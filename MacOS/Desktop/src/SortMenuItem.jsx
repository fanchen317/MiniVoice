import ActionButton from '../../../Shared/UI/src/components/ActionButton.jsx';
import React from 'react';

// Always reserve the check column, including for unselected options.
export function SortMenuItem({selected,children,className='',...props}){
  return <ActionButton {...props} className={`sort-menu-item ${className}`} aria-pressed={selected}>
    <span className="sort-menu-check" aria-hidden="true">{selected?'✓':''}</span>
    <span className="sort-menu-label">{children}</span>
  </ActionButton>;
}
