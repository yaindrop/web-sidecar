import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ConfigProvider, theme } from 'antd';
import DisplayList from './components/DisplayList';
import StreamViewer from './components/StreamViewer';
import { useIsDarkMode } from './utils/dark-mode';

function App() {
  const isDarkMode = useIsDarkMode();
  const algorithm = isDarkMode ? theme.darkAlgorithm : theme.defaultAlgorithm;

  return (
    <ConfigProvider theme={{ algorithm }}>
      <Router>
        <Routes>
          <Route path="/" element={<DisplayList />} />
          <Route path="/stream/:id" element={<StreamViewer />} />
        </Routes>
      </Router>
    </ConfigProvider>
  );
}

export default App;
