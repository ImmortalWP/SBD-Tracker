import { useState } from 'react';

// Formulas
const epley = (w, r) => r === 1 ? w : w * (1 + r / 30);
const brzycki = (w, r) => r === 1 ? w : w * (36 / (37 - r));
const lombardi = (w, r) => w * Math.pow(r, 0.1);

const PLATE_PAIRS = [25, 20, 15, 10, 5, 2.5, 1.25];

export default function Calculators() {
  const [activeCalc, setActiveCalc] = useState('1rm');
  
  // 1RM state
  const [rmWeight, setRmWeight] = useState('');
  const [rmReps, setRmReps] = useState('');
  
  // Plate calc state
  const [plateWeight, setPlateWeight] = useState('');
  const [barWeight, setBarWeight] = useState('20');

  // Warmup state
  const [workWeight, setWorkWeight] = useState('');

  const calcs = [
    { id: '1rm', label: '1RM', icon: '🏋️' },
    { id: 'plate', label: 'Plates', icon: '🔴' },
    { id: 'warmup', label: 'Warm-up', icon: '🔥' },
  ];

  // 1RM results
  const w = Number(rmWeight);
  const r = Number(rmReps);
  const e1rm = w && r ? epley(w, r) : 0;
  const b1rm = w && r ? brzycki(w, r) : 0;
  const avg1rm = e1rm && b1rm ? (e1rm + b1rm) / 2 : 0;

  const repMaxes = avg1rm > 0 ? [1,2,3,4,5,6,8,10,12,15,20].map(reps => ({
    reps,
    weight: Math.round(avg1rm * (1 - (reps - 1) * 0.025) * 10) / 10,
  })) : [];

  // Plate calc
  const targetPlate = Number(plateWeight);
  const bar = Number(barWeight);
  const perSide = targetPlate > bar ? (targetPlate - bar) / 2 : 0;
  
  const getPlates = (weight) => {
    const plates = [];
    let remaining = weight;
    for (const plate of PLATE_PAIRS) {
      while (remaining >= plate) {
        plates.push(plate);
        remaining -= plate;
        remaining = Math.round(remaining * 100) / 100;
      }
    }
    return plates;
  };
  const sideLoad = getPlates(perSide);

  // Warmup
  const ww = Number(workWeight);
  const warmupSets = ww > 0 ? [
    { pct: 0, weight: bar, reps: 10, label: 'Bar only' },
    { pct: 40, weight: Math.round(ww * 0.4 / 2.5) * 2.5, reps: 8, label: '40%' },
    { pct: 60, weight: Math.round(ww * 0.6 / 2.5) * 2.5, reps: 5, label: '60%' },
    { pct: 75, weight: Math.round(ww * 0.75 / 2.5) * 2.5, reps: 3, label: '75%' },
    { pct: 85, weight: Math.round(ww * 0.85 / 2.5) * 2.5, reps: 2, label: '85%' },
    { pct: 90, weight: Math.round(ww * 0.90 / 2.5) * 2.5, reps: 1, label: '90%' },
  ] : [];

  return (
    <div className="space-y-5 animate-fade-in">
      <h1 className="text-2xl font-extrabold text-sl-text tracking-tight">Calculators</h1>

      {/* Tabs */}
      <div className="flex gap-1 bg-sl-card rounded-xl p-1">
        {calcs.map(c => (
          <button key={c.id} onClick={() => setActiveCalc(c.id)}
            className={`flex-1 py-2.5 rounded-lg text-xs font-semibold transition-all flex items-center justify-center gap-1.5 ${
              activeCalc === c.id ? 'bg-sl-green text-white' : 'text-sl-textMuted'
            }`}>
            <span>{c.icon}</span> {c.label}
          </button>
        ))}
      </div>

      {/* 1RM Calculator */}
      {activeCalc === '1rm' && (
        <div className="space-y-4 animate-fade-in">
          <div className="card p-4 space-y-3">
            <h2 className="text-sm font-bold text-sl-text">One Rep Max Calculator</h2>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="section-title block mb-1">Weight (kg)</label>
                <input type="number" value={rmWeight} onChange={e => setRmWeight(e.target.value)}
                  placeholder="100" className="input-field" id="calc-weight" />
              </div>
              <div>
                <label className="section-title block mb-1">Reps</label>
                <input type="number" value={rmReps} onChange={e => setRmReps(e.target.value)}
                  placeholder="5" className="input-field" id="calc-reps" min="1" max="30" />
              </div>
            </div>
          </div>

          {avg1rm > 0 && (
            <>
              <div className="card p-5 text-center bg-gradient-to-r from-sl-green/10 to-sl-green/5 border-sl-green/20">
                <p className="text-xs text-sl-textMuted mb-1">Estimated 1RM</p>
                <p className="text-4xl font-extrabold text-sl-green">{Math.round(avg1rm)} <span className="text-lg text-sl-textMuted">kg</span></p>
                <div className="flex justify-center gap-4 mt-2 text-xs text-sl-textMuted">
                  <span>Epley: {Math.round(e1rm)}kg</span>
                  <span>Brzycki: {Math.round(b1rm)}kg</span>
                </div>
              </div>

              <div className="card overflow-hidden">
                <div className="grid grid-cols-2 gap-px bg-sl-border">
                  {repMaxes.map(rm => (
                    <div key={rm.reps} className="bg-sl-card p-3 flex items-center justify-between">
                      <span className="text-xs text-sl-textMuted">{rm.reps}RM</span>
                      <span className="text-sm font-bold font-mono text-sl-text">{rm.weight} kg</span>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* Plate Calculator */}
      {activeCalc === 'plate' && (
        <div className="space-y-4 animate-fade-in">
          <div className="card p-4 space-y-3">
            <h2 className="text-sm font-bold text-sl-text">Plate Calculator</h2>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="section-title block mb-1">Target Weight (kg)</label>
                <input type="number" value={plateWeight} onChange={e => setPlateWeight(e.target.value)}
                  placeholder="140" className="input-field" id="plate-weight" />
              </div>
              <div>
                <label className="section-title block mb-1">Bar Weight (kg)</label>
                <input type="number" value={barWeight} onChange={e => setBarWeight(e.target.value)}
                  placeholder="20" className="input-field" id="bar-weight" />
              </div>
            </div>
          </div>

          {sideLoad.length > 0 && (
            <div className="card p-5">
              <p className="section-title mb-3">Each Side: {perSide} kg</p>
              <div className="flex items-center justify-center gap-1 py-4">
                {/* Bar end */}
                <div className="w-2 h-3 bg-sl-textMuted rounded-sm" />
                {/* Plates */}
                {sideLoad.map((plate, i) => {
                  const h = Math.max(24, Math.min(56, plate * 2.2));
                  const colors = {
                    25: 'bg-red-500', 20: 'bg-blue-500', 15: 'bg-yellow-500',
                    10: 'bg-green-500', 5: 'bg-white', 2.5: 'bg-red-300', 1.25: 'bg-gray-400',
                  };
                  return (
                    <div key={i} className={`w-3 rounded-sm ${colors[plate] || 'bg-gray-500'}`}
                      style={{ height: `${h}px` }} title={`${plate}kg`} />
                  );
                })}
                {/* Bar */}
                <div className="w-20 h-2 bg-sl-textMuted rounded-full" />
                {/* Mirror */}
                {[...sideLoad].reverse().map((plate, i) => {
                  const h = Math.max(24, Math.min(56, plate * 2.2));
                  const colors = {
                    25: 'bg-red-500', 20: 'bg-blue-500', 15: 'bg-yellow-500',
                    10: 'bg-green-500', 5: 'bg-white', 2.5: 'bg-red-300', 1.25: 'bg-gray-400',
                  };
                  return (
                    <div key={i} className={`w-3 rounded-sm ${colors[plate] || 'bg-gray-500'}`}
                      style={{ height: `${h}px` }} />
                  );
                })}
                <div className="w-2 h-3 bg-sl-textMuted rounded-sm" />
              </div>
              <div className="flex flex-wrap gap-2 justify-center mt-3">
                {sideLoad.map((plate, i) => (
                  <span key={i} className="badge-muted text-xs">{plate}kg</span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Warmup Calculator */}
      {activeCalc === 'warmup' && (
        <div className="space-y-4 animate-fade-in">
          <div className="card p-4">
            <h2 className="text-sm font-bold text-sl-text mb-3">Warm-up Calculator</h2>
            <div>
              <label className="section-title block mb-1">Working Weight (kg)</label>
              <input type="number" value={workWeight} onChange={e => setWorkWeight(e.target.value)}
                placeholder="100" className="input-field" id="warmup-weight" />
            </div>
          </div>

          {warmupSets.length > 0 && (
            <div className="card overflow-hidden">
              <div className="p-3 bg-sl-surface text-[10px] font-semibold text-sl-textMuted uppercase grid grid-cols-4 gap-2">
                <span>Set</span><span>Weight</span><span>Reps</span><span>%</span>
              </div>
              {warmupSets.map((s, i) => (
                <div key={i} className="p-3 border-t border-sl-border grid grid-cols-4 gap-2 text-sm">
                  <span className="text-sl-textMuted">{i + 1}</span>
                  <span className="font-mono font-semibold text-sl-text">{s.weight} kg</span>
                  <span className="text-sl-textSecondary">× {s.reps}</span>
                  <span className="text-sl-green font-semibold">{s.label}</span>
                </div>
              ))}
              <div className="p-3 border-t-2 border-sl-green/30 grid grid-cols-4 gap-2 text-sm bg-sl-green/5">
                <span className="text-sl-green font-bold">Work</span>
                <span className="font-mono font-bold text-sl-green">{ww} kg</span>
                <span className="text-sl-textSecondary">× your reps</span>
                <span className="text-sl-green font-bold">100%</span>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
