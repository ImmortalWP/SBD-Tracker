import { useState, useEffect, useRef, useCallback } from 'react';
import { HiPlay, HiPause, HiRefresh, HiX } from 'react-icons/hi';

const PRESETS = [30, 60, 90, 120, 180, 300];

export default function RestTimer({ isOpen, onClose, defaultSeconds = 90 }) {
  const [seconds, setSeconds] = useState(defaultSeconds);
  const [remaining, setRemaining] = useState(defaultSeconds);
  const [isRunning, setIsRunning] = useState(false);
  const [isFinished, setIsFinished] = useState(false);
  const intervalRef = useRef(null);
  const audioRef = useRef(null);

  useEffect(() => {
    if (isOpen) {
      setRemaining(seconds);
      setIsRunning(true);
      setIsFinished(false);
    }
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isOpen]);

  useEffect(() => {
    if (isRunning && remaining > 0) {
      intervalRef.current = setInterval(() => {
        setRemaining(prev => {
          if (prev <= 1) {
            clearInterval(intervalRef.current);
            setIsRunning(false);
            setIsFinished(true);
            // Play sound
            try {
              const ctx = new (window.AudioContext || window.webkitAudioContext)();
              const osc = ctx.createOscillator();
              const gain = ctx.createGain();
              osc.connect(gain);
              gain.connect(ctx.destination);
              osc.frequency.value = 880;
              gain.gain.value = 0.3;
              osc.start();
              osc.stop(ctx.currentTime + 0.3);
              setTimeout(() => {
                const osc2 = ctx.createOscillator();
                const gain2 = ctx.createGain();
                osc2.connect(gain2);
                gain2.connect(ctx.destination);
                osc2.frequency.value = 1100;
                gain2.gain.value = 0.3;
                osc2.start();
                osc2.stop(ctx.currentTime + 0.3);
              }, 350);
            } catch (e) {}
            // Vibrate
            if (navigator.vibrate) navigator.vibrate([200, 100, 200]);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isRunning, remaining]);

  const toggle = () => {
    if (isFinished) {
      setRemaining(seconds);
      setIsFinished(false);
      setIsRunning(true);
    } else {
      setIsRunning(!isRunning);
    }
  };

  const reset = () => {
    setRemaining(seconds);
    setIsRunning(false);
    setIsFinished(false);
  };

  const selectPreset = (s) => {
    setSeconds(s);
    setRemaining(s);
    setIsRunning(true);
    setIsFinished(false);
  };

  const formatTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  const progress = seconds > 0 ? ((seconds - remaining) / seconds) * 100 : 0;

  if (!isOpen) return null;

  return (
    <div className="fixed bottom-20 left-1/2 -translate-x-1/2 z-50 animate-slide-up" id="rest-timer">
      <div className="card p-4 w-72 border-sl-green/30">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs font-semibold uppercase tracking-wider text-sl-textMuted">Rest Timer</span>
          <button onClick={onClose} className="text-sl-textMuted hover:text-sl-text">
            <HiX className="text-base" />
          </button>
        </div>

        {/* Progress ring */}
        <div className="flex items-center justify-center mb-3">
          <div className="relative w-28 h-28">
            <svg className="w-full h-full -rotate-90" viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="44" fill="none" stroke="#2a2a2a" strokeWidth="6" />
              <circle
                cx="50" cy="50" r="44" fill="none"
                stroke={isFinished ? '#EF5350' : '#4CAF50'}
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={`${2 * Math.PI * 44}`}
                strokeDashoffset={`${2 * Math.PI * 44 * (1 - progress / 100)}`}
                className="transition-all duration-1000"
              />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center">
              <span className={`text-2xl font-bold font-mono ${isFinished ? 'text-sl-red animate-pulse' : 'text-sl-text'}`}>
                {formatTime(remaining)}
              </span>
            </div>
          </div>
        </div>

        {/* Controls */}
        <div className="flex items-center justify-center gap-3 mb-3">
          <button onClick={reset} className="btn-icon w-9 h-9">
            <HiRefresh className="text-lg" />
          </button>
          <button onClick={toggle} className={`w-12 h-12 rounded-full flex items-center justify-center text-white ${isFinished ? 'bg-sl-red' : 'bg-sl-green'} active:scale-95 transition-all`}>
            {isRunning ? <HiPause className="text-xl" /> : <HiPlay className="text-xl ml-0.5" />}
          </button>
          <button onClick={onClose} className="btn-icon w-9 h-9 text-sl-textMuted">
            <HiX className="text-lg" />
          </button>
        </div>

        {/* Presets */}
        <div className="flex gap-1.5 justify-center">
          {PRESETS.map(s => (
            <button
              key={s}
              onClick={() => selectPreset(s)}
              className={`px-2 py-1 rounded-md text-xs font-semibold transition-all ${
                seconds === s ? 'bg-sl-green/20 text-sl-green' : 'bg-sl-surface text-sl-textMuted hover:text-sl-text'
              }`}
            >
              {s >= 60 ? `${s / 60}m` : `${s}s`}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
