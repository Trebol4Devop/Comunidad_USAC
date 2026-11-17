import { describe, it, expect } from 'vitest';
import { detectImageType } from '../src/validators';

describe('Validators: detectImageType', () => {
  it('detects JPEG from magic bytes FF D8 FF', () => {
    const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/jpeg', ext: 'jpg' });
  });

  it('detects PNG from magic bytes 89 50 4E 47 0D 0A 1A 0A', () => {
    const bytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/png', ext: 'png' });
  });

  it('detects WebP from RIFF ... WEBP magic bytes', () => {
    const bytes = new Uint8Array([
      0x52, 0x49, 0x46, 0x46, // RIFF
      0x24, 0x00, 0x00, 0x00, // file size
      0x57, 0x45, 0x42, 0x50, // WEBP
      0x56, 0x50, 0x38, 0x20, // VP8
    ]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/webp', ext: 'webp' });
  });

  it('rejects PDF and garbage bytes', () => {
    const pdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34]);
    expect(detectImageType(pdfBytes)).toBeNull();

    expect(detectImageType(new Uint8Array([0x00, 0x01, 0x02]))).toBeNull();
    expect(detectImageType(new Uint8Array([0x48, 0x65, 0x6c, 0x6c, 0x6f]))).toBeNull();
    expect(detectImageType(new Uint8Array([]))).toBeNull();
  });
});
