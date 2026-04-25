use anyhow::{bail, Context};
use image::imageops::FilterType;

#[derive(Clone, Copy, Debug)]
struct RgbSample {
    r: u8,
    g: u8,
    b: u8,
}

impl RgbSample {
    fn channel(self, channel: usize) -> u8 {
        match channel {
            0 => self.r,
            1 => self.g,
            _ => self.b,
        }
    }
}

/// for Flutter
/// 从图片原始字节中提取稳定的 RGB 主色列表，返回值不包含 alpha。
pub fn extract_dominant_colors(image_bytes: Vec<u8>, max_colors: u8) -> anyhow::Result<Vec<u32>> {
    if image_bytes.is_empty() {
        bail!("image bytes are empty");
    }
    if max_colors == 0 {
        bail!("max_colors must be greater than zero");
    }

    let target_count = usize::from(max_colors.min(8));
    let image = image::load_from_memory(&image_bytes).context("failed to decode image")?;
    let resized = image.resize(64, 64, FilterType::Triangle).to_rgba8();

    let mut pixels = Vec::with_capacity((resized.width() * resized.height()) as usize);
    for pixel in resized.pixels() {
        let [r, g, b, a] = pixel.0;
        if a < 24 {
            continue;
        }
        pixels.push(RgbSample { r, g, b });
    }

    if pixels.is_empty() {
        bail!("image does not contain visible pixels");
    }

    let buckets = median_cut(pixels, target_count);
    let mut colors = buckets
        .into_iter()
        .filter_map(average_bucket)
        .collect::<Vec<_>>();

    colors.sort_by(|left, right| right.weight.cmp(&left.weight));

    let mut result = Vec::with_capacity(colors.len());
    for color in colors {
        if result
            .iter()
            .all(|existing| color_distance_sq(*existing, color.rgb) > 24 * 24)
        {
            result.push(color.rgb);
        }
    }

    Ok(result)
}

#[derive(Clone, Copy)]
struct WeightedColor {
    rgb: u32,
    weight: usize,
}

fn median_cut(pixels: Vec<RgbSample>, target_count: usize) -> Vec<Vec<RgbSample>> {
    let mut buckets = vec![pixels];

    while buckets.len() < target_count {
        let Some(split_index) = buckets
            .iter()
            .enumerate()
            .filter(|(_, bucket)| bucket.len() > 1)
            .filter_map(|(index, bucket)| {
                let (range, _) = widest_channel(bucket);
                if range == 0 {
                    None
                } else {
                    Some((index, usize::from(range) * bucket.len()))
                }
            })
            .max_by_key(|(_, score)| *score)
            .map(|(index, _)| index)
        else {
            break;
        };

        let mut bucket = buckets.swap_remove(split_index);
        let (_, channel) = widest_channel(&bucket);
        bucket.sort_by_key(|sample| sample.channel(channel));
        let right = bucket.split_off(bucket.len() / 2);
        if bucket.is_empty() || right.is_empty() {
            buckets.push(bucket);
            buckets.push(right);
            break;
        }
        buckets.push(bucket);
        buckets.push(right);
    }

    buckets
}

fn widest_channel(bucket: &[RgbSample]) -> (u8, usize) {
    let mut min = [u8::MAX; 3];
    let mut max = [u8::MIN; 3];

    for sample in bucket {
        for channel in 0..3 {
            let value = sample.channel(channel);
            min[channel] = min[channel].min(value);
            max[channel] = max[channel].max(value);
        }
    }

    let ranges = [
        max[0].saturating_sub(min[0]),
        max[1].saturating_sub(min[1]),
        max[2].saturating_sub(min[2]),
    ];

    ranges
        .iter()
        .copied()
        .enumerate()
        .max_by_key(|(_, range)| *range)
        .map(|(channel, range)| (range, channel))
        .unwrap_or((0, 0))
}

fn average_bucket(bucket: Vec<RgbSample>) -> Option<WeightedColor> {
    if bucket.is_empty() {
        return None;
    }

    let weight = bucket.len();
    let mut r = 0u64;
    let mut g = 0u64;
    let mut b = 0u64;
    for sample in bucket {
        r += u64::from(sample.r);
        g += u64::from(sample.g);
        b += u64::from(sample.b);
    }

    let divisor = weight as u64;
    let r = (r / divisor) as u32;
    let g = (g / divisor) as u32;
    let b = (b / divisor) as u32;

    Some(WeightedColor {
        rgb: (r << 16) | (g << 8) | b,
        weight,
    })
}

fn color_distance_sq(left: u32, right: u32) -> i32 {
    let lr = ((left >> 16) & 0xFF) as i32;
    let lg = ((left >> 8) & 0xFF) as i32;
    let lb = (left & 0xFF) as i32;
    let rr = ((right >> 16) & 0xFF) as i32;
    let rg = ((right >> 8) & 0xFF) as i32;
    let rb = (right & 0xFF) as i32;

    let dr = lr - rr;
    let dg = lg - rg;
    let db = lb - rb;
    dr * dr + dg * dg + db * db
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
    fn extracts_multiple_color_image() {
        let bytes = encode_png(16, 8, |x, _| {
            if x < 8 {
                Rgba([0xD8, 0x24, 0x3C, 0xFF])
            } else {
                Rgba([0x24, 0x90, 0xD8, 0xFF])
            }
        });

        let colors = extract_dominant_colors(bytes, 4).unwrap();

        assert!(colors.iter().any(|color| is_close(*color, 0xD8243C, 8)));
        assert!(colors.iter().any(|color| is_close(*color, 0x2490D8, 8)));
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
