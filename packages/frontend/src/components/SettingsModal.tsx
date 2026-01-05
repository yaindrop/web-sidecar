import React, { useEffect, useState } from 'react';
import { Modal, Form, Slider, message, Select, Switch } from 'antd';
import { getConfig, updateConfig } from '../api';

interface SettingsModalProps {
  open: boolean;
  onClose: () => void;
}

const dimensionOptions = [
  { value: 0, label: 'No Limit' },
  { value: 480, label: '480p' },
  { value: 720, label: '720p' },
  { value: 1080, label: '1080p' },
  { value: 1280, label: '1280' },
  { value: 1440, label: '1440' },
  { value: 1920, label: '1920 (FHD)' },
  { value: 2560, label: '2560 (2K/QHD)' },
  { value: 3840, label: '3840 (4K UHD)' },
];

const targetFpsOptions = [
  { value: 15, label: '15 FPS' },
  { value: 30, label: '30 FPS' },
  { value: 60, label: '60 FPS' },
  { value: 90, label: '90 FPS' },
  { value: 120, label: '120 FPS' },
];

const SettingsModal: React.FC<SettingsModalProps> = ({ open, onClose }) => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (open) {
      setLoading(true);
      getConfig()
        .then((config) => {
          form.setFieldsValue(config);
        })
        .catch(() => {
          message.error('Failed to load settings');
        })
        .finally(() => {
          setLoading(false);
        });
    }
  }, [open, form]);

  const handleOk = async () => {
    try {
      const values = await form.validateFields();
      setLoading(true);
      await updateConfig(values);
      message.success('Settings updated');
      onClose();
    } catch (error) {
      console.error(error);
      message.error('Failed to update settings');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      title="Settings"
      open={open}
      onOk={handleOk}
      onCancel={onClose}
      confirmLoading={loading}
      maskClosable={false}
    >
      <Form form={form} layout="vertical">
        <Form.Item
          name="maxDimension"
          label="Max Dimension"
          rules={[{ required: true, message: 'Please select max dimension' }]}
          help="The maximum width or height of the video stream"
        >
          <Select options={dimensionOptions} />
        </Form.Item>
        <Form.Item
          name="targetFps"
          label="Target FPS"
          initialValue={60}
          help="Maximum frames per second"
        >
          <Select options={targetFpsOptions} />
        </Form.Item>
        <Form.Item
          name="videoQuality"
          label="Video Quality"
          rules={[{ required: true, message: 'Please input video quality' }]}
          help="JPEG compression quality (0.1 - 1.0)"
        >
          <Slider min={0.1} max={1.0} step={0.05} />
        </Form.Item>
        <Form.Item
          name="dropFramesWhenBusy"
          label="Drop Frames When Busy"
          valuePropName="checked"
          help="Drop frames if the network or client is too slow"
        >
          <Switch />
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default SettingsModal;
