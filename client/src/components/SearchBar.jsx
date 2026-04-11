import { HiSearch, HiX } from 'react-icons/hi';

export default function SearchBar({ blockFilter, dayFilter, onBlockChange, onDayChange, onClear }) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const hasFilters = blockFilter || dayFilter;

  return (
    <div className="flex flex-wrap items-center gap-3">
      {/* Block search */}
      <div className="relative">
        <HiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gym-500 text-sm" />
        <input
          type="number"
          placeholder="Block #"
          value={blockFilter}
          onChange={(e) => onBlockChange(e.target.value)}
          className="input-base pl-9 w-28"
          id="search-block"
          min="1"
        />
      </div>

      {/* Day filter */}
      <select
        value={dayFilter}
        onChange={(e) => onDayChange(e.target.value)}
        className="input-base w-40 cursor-pointer appearance-none"
        id="filter-day"
      >
        <option value="">All Days</option>
        {days.map((d) => (
          <option key={d} value={d}>{d}</option>
        ))}
      </select>

      {/* Clear */}
      {hasFilters && (
        <button onClick={onClear} className="btn-ghost flex items-center gap-1 text-xs" id="clear-filters">
          <HiX className="text-sm" />
          Clear
        </button>
      )}
    </div>
  );
}
