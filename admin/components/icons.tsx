// Line icons, 20px, drawn in the current text colour.
const base = {
  width: 20,
  height: 20,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
};

export const Icons = {
  dashboard: () => (
    <svg {...base}><rect x="3" y="3" width="7" height="9" rx="1.5" /><rect x="14" y="3" width="7" height="5" rx="1.5" /><rect x="14" y="12" width="7" height="9" rx="1.5" /><rect x="3" y="16" width="7" height="5" rx="1.5" /></svg>
  ),
  users: () => (
    <svg {...base}><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5" /><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18.5 14.8c1.6.8 2.7 2.6 3 5.2" /></svg>
  ),
  flag: () => (
    <svg {...base}><path d="M5 21V4" /><path d="M5 4h11l-2 4 2 4H5" /></svg>
  ),
  feed: () => (
    <svg {...base}><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M7 9h10M7 13h10M7 17h6" /></svg>
  ),
  community: () => (
    <svg {...base}><circle cx="12" cy="7" r="3" /><circle cx="5" cy="10" r="2.2" /><circle cx="19" cy="10" r="2.2" /><path d="M7 20c.6-3 2.6-5 5-5s4.4 2 5 5M1.5 19c.3-2 1.5-3.3 3.3-3.6M22.5 19c-.3-2-1.5-3.3-3.3-3.6" /></svg>
  ),
  chat: () => (
    <svg {...base}><path d="M4 5h16v11H9l-5 4z" /></svg>
  ),
  megaphone: () => (
    <svg {...base}><path d="M3 10v4h3l7 5V5L6 10z" /><path d="M17 9a4 4 0 0 1 0 6" /></svg>
  ),
  trophy: () => (
    <svg {...base}><path d="M8 4h8v5a4 4 0 0 1-8 0z" /><path d="M8 6H4a3 3 0 0 0 4 4M16 6h4a3 3 0 0 1-4 4M12 13v4M8 21h8M9 17h6" /></svg>
  ),
  menu: () => (
    <svg {...base}><path d="M4 7h16M4 12h16M4 17h16" /></svg>
  ),
  close: () => (
    <svg {...base}><path d="M6 6l12 12M18 6L6 18" /></svg>
  ),
  out: () => (
    <svg {...base}><path d="M14 4h5v16h-5M10 8l-4 4 4 4M6 12h10" /></svg>
  ),
  search: () => (
    <svg {...base}><circle cx="11" cy="11" r="6.5" /><path d="M20 20l-4.2-4.2" /></svg>
  ),
};
