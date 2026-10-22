import React from 'react';
/** Shared semantics; each product family supplies its own visual skin. */
export default function ActionButton({label,children,selected,disabled=false,busy=false,type='button',className='',...props}){
 return <button {...props} type={type} className={className} title={label} aria-label={label} aria-pressed={selected===undefined?undefined:Boolean(selected)} aria-busy={busy||undefined} disabled={disabled||busy} data-mv-component="action-button">{children}</button>;
}
