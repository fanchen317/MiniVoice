import React from 'react';
import ActionButton from './ActionButton.jsx';
import './artworkFraming.css';

/** Only framing is controlled here; sharp/blur appearance remains independent. */
export default function ArtworkFramingOptions({value='smart',onValueChange,presentation='mobile'}){
 return <section className="mv-artwork-framing" data-mv-component="artwork-framing-options" data-input-family={presentation}><h3>全屏插图样式</h3><div role="group" aria-label="全屏插图样式">{[['center','居中'],['smart','智能'],['manual','手动']].map(([mode,label])=><ActionButton key={mode} selected={value===mode} onClick={()=>onValueChange(mode)}>{label}</ActionButton>)}</div></section>;
}
