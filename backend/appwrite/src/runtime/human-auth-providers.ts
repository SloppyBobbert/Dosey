const supported = new Set(['google', 'email']);

export function parseHumanAuthProviders(value: string | undefined): readonly string[] {
  if (value == null) return ['google'];
  const providers = value.split(',').map((provider) => provider.trim());
  if (providers.length === 0 || providers.some((provider) => provider.length === 0)) {
    throw new Error('Invalid human provider configuration.');
  }
  if (new Set(providers).size !== providers.length) {
    throw new Error('Invalid human provider configuration.');
  }
  if (providers.some((provider) => !supported.has(provider))) throw new Error('Unsupported human provider.');
  return providers;
}
