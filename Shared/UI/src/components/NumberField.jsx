import React from 'react';
import ActionButton from './ActionButton.jsx';
export default function NumberField({label,value,onValueChange,step=1,min=-Infinity,max=Infinity,disabled=false}){
 const parsed=Number(value),valid=String(value).trim()!==''&&Number.isFinite(parsed),decimals=Math.min(8,Math.max(0,(String(step).split('.')[1]||'').length));
 function move(delta){const next=Math.max(min,Math.min(max,(valid?parsed:0)+delta*step));onValueChange(next.toFixed(decimals));}
 return <span className="mv-number-field" data-mv-component="number-field"><ActionButton label={`减少${label}`} disabled={disabled||valid&&parsed<=min} onClick={()=>move(-1)}>−</ActionButton><input type="text" inputMode="decimal" role="spinbutton" aria-label={label} aria-valuenow={valid?parsed:undefined} aria-valuemin={Number.isFinite(min)?min:undefined} aria-valuemax={Number.isFinite(max)?max:undefined} aria-invalid={!valid||undefined} value={value} disabled={disabled} onChange={event=>onValueChange(event.target.value)} onKeyDown={event=>{if(event.key==='ArrowUp'||event.key==='ArrowDown'){event.preventDefault();event.stopPropagation();move(event.key==='ArrowUp'?1:-1);}}}/><ActionButton label={`增加${label}`} disabled={disabled||valid&&parsed>=max} onClick={()=>move(1)}>＋</ActionButton></span>;
}
