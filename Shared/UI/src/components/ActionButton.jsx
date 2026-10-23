import React from 'react';
/** Shared semantics; each product family supplies its own visual skin. */
export default function ActionButton({label,children,selected,disabled=false,busy=false,type='button',className='',feedback='standard',...props}){
 return <button {...props} type={type} className={className} data-mv-feedback={feedback} title={label??props.title} aria-label={label??props['aria-label']} aria-pressed={selected===undefined?props['aria-pressed']:Boolean(selected)} aria-busy={busy||undefined} disabled={disabled||busy} data-mv-component={props['data-mv-component']||'action-button'}>{children}</button>;
}
