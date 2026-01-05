import { useParams, useNavigate } from 'react-router-dom';
import { Tooltip } from 'antd';
import { ArrowLeft, Maximize, Minimize } from 'lucide-react';
import { useRef, useEffect, useState } from 'react';

import { cn } from '../utils/cn';
import { useIsFullscreen, useToggleFullscreen } from '../utils/fullscreen';

// MARK: ManagedStream

const ManagedStream = ({ src, ...props }: React.ImgHTMLAttributes<HTMLImageElement>) => {
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const currentImg = imgRef.current;
    if (currentImg) {
      currentImg.src = src ?? '';
    }
    return () => {
      if (currentImg) {
        currentImg.src = '';
      }
    };
  }, [src]);

  return <img ref={imgRef} src={src} {...props} />;
};

// MARK: StreamViewerButton

interface StreamViewerButtonProps {
  onClick: () => void;
  icon: React.ReactNode;
}

const StreamViewerButton = ({ onClick, icon }: StreamViewerButtonProps) => (
  <div
    className={cn(
      'w-10 h-10 rounded-full bg-white/10 border border-white/10 text-white transition-all flex items-center justify-center cursor-pointer',
      'hover:brightness-120',
      'active:brightness-75'
    )}
    onClick={(e) => {
      e.stopPropagation();
      onClick();
    }}
  >
    {icon}
  </div>
);

// MARK: StreamViewer

const StreamViewer = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const containerRef = useRef<HTMLDivElement>(null);

  const isFullscreen = useIsFullscreen();
  const toggleFullscreen = useToggleFullscreen(containerRef);

  const [showControls, setShowControls] = useState(true);
  const timeoutRef = useRef<number | null>(null);

  const resetTimeout = () => {
    if (timeoutRef.current) {
      window.clearTimeout(timeoutRef.current);
    }
    timeoutRef.current = window.setTimeout(() => {
      setShowControls(false);
    }, 3000);
  };

  useEffect(() => {
    resetTimeout();
    return () => {
      if (timeoutRef.current) {
        window.clearTimeout(timeoutRef.current);
      }
    };
  }, [isFullscreen]);

  const lastTapRef = useRef<number>(0);

  const handleActivity = () => {
    setShowControls(true);
    resetTimeout();
  };

  const handleContainerClick = () => {
    handleActivity();
    const now = Date.now();
    if (now - lastTapRef.current < 300) {
      toggleFullscreen();
    }
    lastTapRef.current = now;
  };

  return (
    <div
      ref={containerRef}
      className={cn(
        'w-screen h-screen bg-black flex justify-center items-center relative overflow-hidden',
        isFullscreen && 'w-full h-full',
        !showControls && 'cursor-none'
      )}
      onMouseMove={handleActivity}
      onTouchStart={handleActivity}
      onClick={handleContainerClick}
    >
      <div
        className={cn(
          'absolute top-5 left-5 z-10 transition-opacity duration-300',
          !showControls ? 'opacity-0' : 'opacity-100'
        )}
      >
        <Tooltip title="Back to List">
          <StreamViewerButton onClick={() => navigate('/')} icon={<ArrowLeft size={20} />} />
        </Tooltip>
      </div>

      <div
        className={cn(
          'absolute top-5 right-5 z-10 transition-opacity duration-300',
          !showControls ? 'opacity-0' : 'opacity-100'
        )}
      >
        <Tooltip title={isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}>
          <StreamViewerButton
            onClick={toggleFullscreen}
            icon={isFullscreen ? <Minimize size={20} /> : <Maximize size={20} />}
          />
        </Tooltip>
      </div>

      <ManagedStream
        src={`/v/${id}`}
        alt={`Display ${id} Stream`}
        className="w-full h-full object-contain block"
      />
    </div>
  );
};

export default StreamViewer;
