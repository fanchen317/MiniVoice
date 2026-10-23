import ActionButton from './ActionButton.jsx';
import React from 'react';
export default function CheckControl({label,checked=false,disabled=false,onCheckedChange}){
 return <ActionButton type="button" className="mv-check-control" data-mv-component="checkbox" role="checkbox" aria-label={label} aria-checked={Boolean(checked)} disabled={disabled} onClick={()=>onCheckedChange?.(!checked)} onKeyDown={event=>{if(event.key===' '||event.key==='Enter'){event.preventDefault();event.stopPropagation();}}} onKeyUp={event=>{if(!disabled&&(event.key===' '||event.key==='Enter')){event.preventDefault();event.stopPropagation();onCheckedChange?.(!checked);}}}><span aria-hidden="true">{checked?'✓':''}</span></ActionButton>;
}
