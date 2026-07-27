use anyhow::{bail, Context};
use image::imageops::FilterType;
use std::collections::HashMap;

const MIN_CLUSTER_PERCENT: u64 = 6;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct RgbSample {
    r: u8,
    g: u8,
    b: u8,
}

impl RgbSample {
    fn distance_sq(self, other: Self) -> f64 {
        let left = self.to_oklab();
        let right = other.to_oklab();
        (left.l - right.l).powi(2) + (left.a - right.a).powi(2) + (left.b - right.b).powi(2)
    }

    fn to_oklab(self) -> OkLab {
        let r = srgb_to_linear(self.r);
        let g = srgb_to_linear(self.g);
        let b = srgb_to_linear(self.b);

        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
        let l = l.cbrt();
        let m = m.cbrt();
        let s = s.cbrt();

        OkLab {
            l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
        }
    }
}

#[derive(Clone, Copy)]
struct OkLab {
    l: f64,
    a: f64,
    b: f64,
}

fn srgb_to_linear(value: u8) -> f64 {
    let value = f64::from(value) / 255.0;
    if value <= 0.04045 {
        value / 12.92
    } else {
        ((value + 0.055) / 1.055).powf(2.4)
    }
}

#[derive(Clone, Copy, Debug)]
struct HistogramBin {
    red_sum: u64,
    green_sum: u64,
    blue_sum: u64,
    weight: u64,
}

impl HistogramBin {
    fn color(self) -> RgbSample {
        RgbSample {
            r: (self.red_sum / self.weight) as u8,
            g: (self.green_sum / self.weight) as u8,
            b: (self.blue_sum / self.weight) as u8,
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct WeightedColor {
    rgb: u32,
    weight: u64,
}

/// Extracts dominant RGB colors from encoded image bytes for Flutter.
pub fn extract_dominant_colors(image_bytes: Vec<u8>, max_colors: u8) -> anyhow::Result<Vec<u32>> {
    if image_bytes.is_empty() {
        bail!("image bytes are empty");
    }
    if max_colors == 0 {
        bail!("max_colors must be greater than zero");
    }

    let target_count = usize::from(max_colors.min(8));
    let image = image::load_from_memory(&image_bytes).context("failed to decode image")?;
    let resized = image.resize(160, 160, FilterType::Triangle).to_rgba8();
    let mut histogram = HashMap::<u16, HistogramBin>::new();
    let mut total_weight = 0u64;

    let width = resized.width() as f64;
    let height = resized.height() as f64;
    for (index, pixel) in resized.pixels().enumerate() {
        let [r, g, b, a] = pixel.0;
        if a < 24 {
            continue;
        }

        let x = (index as u32 % resized.width()) as f64;
        let y = (index as u32 / resized.width()) as f64;
        let center_x = ((x + 0.5) / width - 0.5) * 2.0;
        let center_y = ((y + 0.5) / height - 0.5) * 2.0;
        let center_distance = (center_x * center_x + center_y * center_y).sqrt();
        let spatial_weight = (0.72 + 0.28 * (1.0 - center_distance.min(1.0))).max(0.0);
        let weight = (f64::from(a) * spatial_weight).round() as u64;
        if weight == 0 {
            continue;
        }
        let key = (u16::from(r >> 3) << 10) | (u16::from(g >> 3) << 5) | u16::from(b >> 3);
        let bin = histogram.entry(key).or_insert(HistogramBin {
            red_sum: 0,
            green_sum: 0,
            blue_sum: 0,
            weight: 0,
        });
        bin.red_sum += u64::from(r) * weight;
        bin.green_sum += u64::from(g) * weight;
        bin.blue_sum += u64::from(b) * weight;
        bin.weight += weight;
        total_weight += weight;
    }

    if histogram.is_empty() {
        bail!("image does not contain visible pixels");
    }

    let bins = histogram.into_values().collect::<Vec<_>>();
    let average_luminance = weighted_average_luminance(&bins, total_weight);
    let mut colors = cluster_histogram(&bins, target_count);
    colors.sort_by(|left, right| {
        visual_salience_score(*right, total_weight, average_luminance)
            .partial_cmp(&visual_salience_score(
                *left,
                total_weight,
                average_luminance,
            ))
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| right.weight.cmp(&left.weight))
    });
    let has_multiple_colors = colors.len() > 1;
    colors.retain(|color| {
        !has_multiple_colors
            || color.weight.saturating_mul(100) >= total_weight.saturating_mul(MIN_CLUSTER_PERCENT)
    });

    let mut result = Vec::with_capacity(colors.len());
    for color in colors {
        if result
            .iter()
            .all(|existing| color_distance_sq(*existing, color.rgb) > 0.035_f64.powi(2))
        {
            result.push(color.rgb);
        }
    }

    if result.is_empty() {
        if let Some(color) = cluster_histogram(&bins, 1).into_iter().next() {
            result.push(color.rgb);
        }
    }

    Ok(result)
}

fn weighted_average_luminance(bins: &[HistogramBin], total_weight: u64) -> f64 {
    if total_weight == 0 {
        return 0.0;
    }

    bins.iter()
        .map(|bin| relative_luminance(bin.color()) * bin.weight as f64)
        .sum::<f64>()
        / total_weight as f64
}

fn visual_salience_score(color: WeightedColor, total_weight: u64, average_luminance: f64) -> f64 {
    if total_weight == 0 {
        return 0.0;
    }

    let area = color.weight as f64 / total_weight as f64;
    let sample = rgb_sample(color.rgb);
    let saturation = rgb_saturation(sample);
    let contrast = (relative_luminance(sample) - average_luminance).abs();

    // Area remains the strongest signal, while vivid and contrasting colors
    // can outrank a visually flat color that occupies a slightly larger area.
    area.powf(0.50) * (0.50 + saturation * 0.35 + contrast * 0.15)
}

fn rgb_sample(rgb: u32) -> RgbSample {
    RgbSample {
        r: ((rgb >> 16) & 0xFF) as u8,
        g: ((rgb >> 8) & 0xFF) as u8,
        b: (rgb & 0xFF) as u8,
    }
}

fn rgb_saturation(sample: RgbSample) -> f64 {
    let max = f64::from(sample.r.max(sample.g).max(sample.b));
    let min = f64::from(sample.r.min(sample.g).min(sample.b));
    if max == 0.0 {
        return 0.0;
    }
    (max - min) / max
}

fn relative_luminance(sample: RgbSample) -> f64 {
    (0.2126 * f64::from(sample.r) + 0.7152 * f64::from(sample.g) + 0.0722 * f64::from(sample.b))
        / 255.0
}

fn cluster_histogram(bins: &[HistogramBin], target_count: usize) -> Vec<WeightedColor> {
    let cluster_count = target_count.min(bins.len()).max(1);
    let mut centroids = Vec::with_capacity(cluster_count);
    centroids.push(bins.iter().max_by_key(|bin| bin.weight).unwrap().color());

    while centroids.len() < cluster_count {
        let next = bins
            .iter()
            .map(|bin| {
                let color = bin.color();
                let distance = centroids
                    .iter()
                    .map(|centroid| color.distance_sq(*centroid))
                    .reduce(|left, right| left.min(right))
                    .unwrap_or(0.0);
                (color, distance * bin.weight as f64)
            })
            .max_by(|(_, left_score), (_, right_score)| {
                left_score
                    .partial_cmp(right_score)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .map(|(color, _)| color)
            .unwrap();
        if centroids.contains(&next) {
            break;
        }
        centroids.push(next);
    }

    let mut assignments = vec![0usize; bins.len()];
    for _ in 0..10 {
        assign_bins(bins, &centroids, &mut assignments);
        let sums = cluster_sums(bins, &assignments, centroids.len());
        for (centroid, (r, g, b, weight)) in centroids.iter_mut().zip(sums) {
            if weight > 0 {
                *centroid = RgbSample {
                    r: (r / weight) as u8,
                    g: (g / weight) as u8,
                    b: (b / weight) as u8,
                };
            }
        }
    }

    assign_bins(bins, &centroids, &mut assignments);
    cluster_sums(bins, &assignments, centroids.len())
        .into_iter()
        .filter(|(_, _, _, weight)| *weight > 0)
        .map(|(r, g, b, weight)| WeightedColor {
            rgb: ((r / weight) as u32) << 16 | ((g / weight) as u32) << 8 | (b / weight) as u32,
            weight,
        })
        .collect()
}

fn assign_bins(bins: &[HistogramBin], centroids: &[RgbSample], assignments: &mut [usize]) {
    for (index, bin) in bins.iter().enumerate() {
        let color = bin.color();
        assignments[index] = centroids
            .iter()
            .enumerate()
            .min_by(|(_, left), (_, right)| {
                color
                    .distance_sq(**left)
                    .partial_cmp(&color.distance_sq(**right))
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .map(|(cluster, _)| cluster)
            .unwrap_or(0);
    }
}

fn cluster_sums(
    bins: &[HistogramBin],
    assignments: &[usize],
    cluster_count: usize,
) -> Vec<(u64, u64, u64, u64)> {
    let mut sums = vec![(0u64, 0u64, 0u64, 0u64); cluster_count];
    for (bin, cluster) in bins.iter().zip(assignments.iter().copied()) {
        let color = bin.color();
        let sum = &mut sums[cluster];
        sum.0 += u64::from(color.r) * bin.weight;
        sum.1 += u64::from(color.g) * bin.weight;
        sum.2 += u64::from(color.b) * bin.weight;
        sum.3 += bin.weight;
    }
    sums
}

fn color_distance_sq(left: u32, right: u32) -> f64 {
    rgb_sample(left).distance_sq(rgb_sample(right))
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{DynamicImage, ImageBuffer, ImageFormat, Rgba};
    use std::io::Cursor;

    #[test]
    fn rejects_empty_image_bytes() {
        assert!(extract_dominant_colors(vec![], 4).is_err());
    }

    #[test]
    fn rejects_invalid_image_bytes() {
        assert!(extract_dominant_colors(b"not an image".to_vec(), 4).is_err());
    }

    #[test]
    fn extracts_single_color_image() {
        let bytes = encode_png(8, 8, |_, _| Rgba([0x22, 0x88, 0xCC, 0xFF]));
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_eq!(colors.len(), 1);
        assert_close(colors[0], 0x2288CC, 2);
    }

    #[test]
    fn orders_colors_by_visible_area() {
        let bytes = encode_png(100, 10, |x, _| {
            if x < 70 {
                Rgba([0xD8, 0x24, 0x3C, 0xFF])
            } else {
                Rgba([0x24, 0x90, 0xD8, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_close(colors[0], 0xD8243C, 10);
        assert!(colors.iter().any(|color| is_close(*color, 0x2490D8, 10)));
    }

    #[test]
    fn prioritizes_visual_salience_over_flat_area() {
        let bytes = encode_png(100, 10, |x, _| {
            if x < 70 {
                Rgba([0x80, 0x80, 0x80, 0xFF])
            } else {
                Rgba([0xFF, 0x00, 0xAA, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_close(colors[0], 0xFF00AA, 16);
        assert!(colors.iter().any(|color| is_close(*color, 0x808080, 16)));
    }

    #[test]
    fn preserves_neutral_grayscale_colors() {
        let bytes = encode_png(20, 10, |x, _| {
            if x < 10 {
                Rgba([0x22, 0x22, 0x22, 0xFF])
            } else {
                Rgba([0xBB, 0xBB, 0xBB, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert!(colors.iter().all(|color| {
            let red = (color >> 16) & 0xFF;
            let green = (color >> 8) & 0xFF;
            let blue = color & 0xFF;
            red.abs_diff(green) <= 2 && red.abs_diff(blue) <= 2
        }));
    }

    #[test]
    fn center_subject_can_outweigh_a_large_border() {
        let bytes = encode_png(100, 100, |x, y| {
            if (20..80).contains(&x) && (20..80).contains(&y) {
                Rgba([0xE8, 0x30, 0x3A, 0xFF])
            } else {
                Rgba([0x12, 0x12, 0x12, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_close(colors[0], 0xE8303A, 18);
    }

    #[test]
    fn merges_perceptually_near_colors() {
        let bytes = encode_png(20, 10, |x, _| {
            if x < 10 {
                Rgba([0xD0, 0x40, 0x42, 0xFF])
            } else {
                Rgba([0xD8, 0x45, 0x47, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_eq!(colors.len(), 1);
    }

    #[test]
    fn filters_tiny_high_saturation_accents() {
        let bytes = encode_png(100, 100, |x, y| {
            if x < 5 && y < 100 {
                Rgba([0xFF, 0x00, 0xFF, 0xFF])
            } else {
                Rgba([0x54, 0x58, 0x5C, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 6).unwrap();
        assert_close(colors[0], 0x54585C, 8);
        assert!(!colors.iter().any(|color| is_close(*color, 0xFF00FF, 20)));
    }

    #[test]
    fn ignores_transparent_pixels() {
        let bytes = encode_png(20, 10, |x, _| {
            if x < 10 {
                Rgba([0x00, 0xFF, 0x00, 0x00])
            } else {
                Rgba([0x38, 0x64, 0xA0, 0xFF])
            }
        });
        let colors = extract_dominant_colors(bytes, 4).unwrap();
        assert_close(colors[0], 0x3864A0, 8);
        assert!(!colors.iter().any(|color| is_close(*color, 0x00FF00, 20)));
    }

    fn encode_png(width: u32, height: u32, pixel: impl Fn(u32, u32) -> Rgba<u8>) -> Vec<u8> {
        let image = ImageBuffer::from_fn(width, height, pixel);
        let mut output = Cursor::new(Vec::new());
        DynamicImage::ImageRgba8(image)
            .write_to(&mut output, ImageFormat::Png)
            .unwrap();
        output.into_inner()
    }

    fn assert_close(actual: u32, expected: u32, tolerance: i32) {
        assert!(
            is_close(actual, expected, tolerance),
            "actual #{actual:06X} expected #{expected:06X}"
        );
    }

    fn is_close(actual: u32, expected: u32, tolerance: i32) -> bool {
        let ar = ((actual >> 16) & 0xFF) as i32;
        let ag = ((actual >> 8) & 0xFF) as i32;
        let ab = (actual & 0xFF) as i32;
        let er = ((expected >> 16) & 0xFF) as i32;
        let eg = ((expected >> 8) & 0xFF) as i32;
        let eb = (expected & 0xFF) as i32;
        (ar - er).abs() <= tolerance && (ag - eg).abs() <= tolerance && (ab - eb).abs() <= tolerance
    }
}
