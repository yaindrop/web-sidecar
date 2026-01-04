export interface DisplayInfo {
  id: number;
  width: number;
  height: number;
}

export interface AppConfig {
  maxDimension: number;
  videoQuality: number;
}

export const getDisplays = async (): Promise<DisplayInfo[]> => {
  const response = await fetch('/api/displays');
  if (!response.ok) {
    throw new Error('Failed to fetch displays');
  }
  return response.json();
};

export const getConfig = async (): Promise<AppConfig> => {
  const response = await fetch('/api/config');
  if (!response.ok) {
    throw new Error('Failed to fetch config');
  }
  return response.json();
};

export const updateConfig = async (config: AppConfig): Promise<void> => {
  const response = await fetch('/api/config', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(config),
  });
  if (!response.ok) {
    throw new Error('Failed to update config');
  }
};
