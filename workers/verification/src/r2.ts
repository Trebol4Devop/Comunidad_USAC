/**
 * Operaciones con Cloudflare R2 para almacenamiento temporal de documentos en revisión.
 */

export async function uploadVerificationDocument(
  bucket: R2Bucket,
  key: string,
  data: Uint8Array | ArrayBuffer | ReadableStream,
  contentType: string
): Promise<R2Object> {
  const object = await bucket.put(key, data, {
    httpMetadata: {
      contentType,
    },
  });

  if (!object) {
    throw new Error('R2 put returned null object');
  }

  return object;
}

export async function deleteVerificationDocument(
  bucket: R2Bucket,
  key: string
): Promise<void> {
  await bucket.delete(key);
}
