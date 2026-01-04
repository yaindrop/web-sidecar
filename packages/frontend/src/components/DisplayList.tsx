import { useEffect, useState } from 'react';
import { Card, Typography, Button, Empty, Layout, Row, Col, Skeleton } from 'antd';
import { Monitor, RefreshCcw, Settings } from 'lucide-react';
import { getDisplays } from '../api';
import type { DisplayInfo } from '../api';
import DisplayCard from './DisplayCard';
import SettingsModal from '../components/SettingsModal';

const { Title, Text } = Typography;
const { Content } = Layout;

const DisplayList = () => {
  const [displays, setDisplays] = useState<DisplayInfo[]>([]);
  const [loading, setLoading] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);

  const fetchDisplays = async () => {
    setLoading(true);
    try {
      const data = await getDisplays();
      setDisplays(data);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDisplays();
  }, []);

  return (
    <Layout className="min-h-screen! transition-colors duration-300">
      <Content className="p-6 md:p-12 max-w-350 mx-auto w-full">
        {/* Header Section */}
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-10 gap-4">
          <div>
            <Title level={2} className="mb-1! flex items-center gap-3">
              <span className="p-2 rounded-lg bg-primary/10 text-primary">
                <Monitor className="w-8 h-8 text-primary" />
              </span>
              Available Displays
            </Title>
            <Text type="secondary" className="text-lg">
              Select a screen to start streaming content
            </Text>
          </div>
          <div className="flex gap-2">
            <Button
              size="large"
              icon={<Settings size={18} />}
              onClick={() => setSettingsOpen(true)}
              className="shadow-md hover:shadow-lg transition-shadow"
            >
              Settings
            </Button>
            <Button
              type="primary"
              size="large"
              icon={<RefreshCcw size={18} />}
              onClick={fetchDisplays}
              loading={loading}
              className="shadow-md hover:shadow-lg transition-shadow"
            >
              Refresh List
            </Button>
          </div>
        </div>

        {loading && displays.length === 0 ? (
          <Row gutter={[24, 24]}>
            {[1, 2, 3, 4].map((i) => (
              <Col key={i} xs={24} sm={12} md={8} lg={6}>
                <Card cover={<div className="h-45 bg-gray-100 dark:bg-gray-800 animate-pulse" />}>
                  <Skeleton active paragraph={{ rows: 2 }} />
                </Card>
              </Col>
            ))}
          </Row>
        ) : displays.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 bg-white dark:bg-[#141414] rounded-2xl border border-dashed border-gray-200 dark:border-gray-700">
            <Empty
              image={Empty.PRESENTED_IMAGE_SIMPLE}
              description={
                <div className="flex flex-col items-center gap-2">
                  <Text strong className="text-lg">
                    No displays detected
                  </Text>
                  <Text type="secondary">Ensure ScreenCaptureKit permissions are granted</Text>
                </div>
              }
            />
            <Button onClick={fetchDisplays} className="mt-4">
              Try Again
            </Button>
          </div>
        ) : (
          <Row gutter={[24, 24]}>
            {displays.map((display) => (
              <Col key={display.id} xs={24} sm={12} md={8} lg={6}>
                <DisplayCard display={display} />
              </Col>
            ))}
          </Row>
        )}
        <SettingsModal open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      </Content>
    </Layout>
  );
};

export default DisplayList;
