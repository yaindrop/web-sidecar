import { Typography, theme, Tag } from 'antd';
import { Monitor } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import type { DisplayInfo } from '../api';
import { cn } from '../utils/cn';

const { Title, Text } = Typography;
const { useToken } = theme;

// MARK: getAspectRatio
/**
 * Calculates the aspect ratio of a given width and height.
 * The aspect ratio is rounded to the nearest fraction with a denominator up to 50.
 */
const getAspectRatio = (width: number, height: number) => {
  const targetRatio = width / height;
  let bestNumerator = width;
  let bestDenominator = height;
  let minError = Number.MAX_VALUE;

  for (let h = 1; h <= 50; h++) {
    const w = Math.round(h * targetRatio);
    if (w > 50) continue;
    const error = Math.abs(w / h - targetRatio);
    if (error < minError) {
      minError = error;
      bestNumerator = w;
      bestDenominator = h;
    }
  }
  return `${bestNumerator}:${bestDenominator}`;
};

// MARK: DisplayCard

interface DisplayCardProps {
  display: DisplayInfo;
}

const DisplayCard = ({ display }: DisplayCardProps) => {
  const navigate = useNavigate();
  const { token } = useToken();

  return (
    <div
      className={cn(
        'DisplayCard',
        'overflow-hidden rounded-lg transition-all size-full cursor-pointer',
        'bg-white dark:bg-neutral-900',
        'hover:scale-105 hover:brightness-110',
        'active:scale-95 active:brightness-90',
        'animate-fade-in'
      )}
      onClick={() => navigate(`/stream/${display.id}`)}
    >
      {/* Display Icon */}
      <div className="h-48" style={{ background: token.colorFillSecondary }}>
        <div className="flex justify-center items-center size-full">
          <Monitor size={96} className="text-gray-400" />
        </div>
      </div>

      {/* Display Info */}
      <div className="p-5 flex flex-col gap-3">
        <div className="flex justify-between items-start">
          <div>
            <Text type="secondary" className="text-xs uppercase tracking-wider font-semibold">
              Display ID
            </Text>
            <Title level={4} className="m-0! mt-0.5!">
              {display.id}
            </Title>
          </div>
          <Tag
            color="blue"
            className="m-0 px-2 py-0.5 rounded-full border-0 bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-300"
          >
            {getAspectRatio(display.width, display.height)}
          </Tag>
        </div>

        <div className="h-px bg-gray-100 dark:bg-gray-800 w-full" />

        {/* Display Details */}
        <div className="grid grid-cols-2 gap-2">
          <div>
            <Text type="secondary" className="text-xs block">
              Width
            </Text>
            <Text strong className="text-base">
              {display.width}px
            </Text>
          </div>
          <div>
            <Text type="secondary" className="text-xs block">
              Height
            </Text>
            <Text strong className="text-base">
              {display.height}px
            </Text>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DisplayCard;
