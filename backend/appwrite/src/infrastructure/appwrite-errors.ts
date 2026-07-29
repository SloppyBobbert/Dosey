import { AppwriteException } from 'node-appwrite';

export function isNotFound(error: unknown): boolean {
  return (
    (error instanceof AppwriteException && error.code === 404) ||
    (typeof error === 'object' && error != null && 'code' in error && error.code === 404)
  );
}
