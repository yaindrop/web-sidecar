import { useState, useEffect } from 'react';

function queryPrefersColorSchemeDark(): MediaQueryList {
  return window.matchMedia('(prefers-color-scheme: dark)');
}

export function useIsDarkMode() {
  const [isDarkMode, setIsDarkMode] = useState(queryPrefersColorSchemeDark().matches);

  useEffect(() => {
    const mediaQuery = queryPrefersColorSchemeDark();
    const handleChange = (e: MediaQueryListEvent) => setIsDarkMode(e.matches);

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  return isDarkMode;
}
