import {useEffect} from 'react';

// A capsule lens is flat in the middle and bends the artwork only at its rim.
// Maps are rebuilt on geometry changes, never while the wall camera is moving.
export function glassDisplacement(width,height,x,y,radius=Math.min(width,height)/2){
  const cx=Math.max(radius,Math.min(width-radius,x)),cy=Math.max(radius,Math.min(height-radius,y));
  const dx=x-cx,dy=y-cy,length=Math.hypot(dx,dy),depth=radius-length;
  const rim=Math.min(7,radius*.38),bend=depth>=0&&depth<rim?Math.sin((1-depth/rim)*Math.PI/2)**2:0;
  return length?[128-dx/length*bend*110,128-dy/length*bend*110]:[128,128];
}
export function useLiquidGlass(style){
  useEffect(()=>{
    if(style!=='wall')return;
    const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg');
    svg.setAttribute('aria-hidden','true');svg.style.cssText='position:absolute;width:0;height:0;pointer-events:none';
    const defs=document.createElementNS(ns,'defs');svg.append(defs);document.body.append(svg);
    const nodes=[...document.querySelectorAll('.style-wall .sidebar,.style-wall .window-tools .icon-button,.wall-search-field,.wall-settings,.style-wall .player.compact')];
    const maps=new Map(),pending=new Set();let timer;
    const light=event=>{const node=event.currentTarget,rect=node.getBoundingClientRect();node.style.setProperty('--glass-light-x',`${(event.clientX-rect.left)/rect.width*100}%`);node.style.setProperty('--glass-light-y',`${(event.clientY-rect.top)/rect.height*100}%`);};
    function update(node){
      const w=node.clientWidth,h=node.clientHeight;if(!w||!h)return;
      const corner=getComputedStyle(node).borderTopLeftRadius;
      const radius=Math.max(0,Math.min(w/2,h/2,corner.endsWith('%')?Math.min(w,h)*parseFloat(corner)/100:parseFloat(corner)||0));
      node.style.setProperty('--lens-radius',`${radius}px`);
      let entry=maps.get(node);
      if(entry&&entry.radius===radius&&Math.abs(entry.w-w)<1&&Math.abs(entry.h-h)<1)return;
      if(!entry){const filter=document.createElementNS(ns,'filter'),id=`mv-lens-${maps.size}`;
        filter.id=id;filter.setAttribute('color-interpolation-filters','sRGB');
        filter.setAttribute('filterUnits','userSpaceOnUse');
        const image=document.createElementNS(ns,'feImage');image.setAttribute('result','lens');image.setAttribute('preserveAspectRatio','none');
        const displacement=document.createElementNS(ns,'feDisplacementMap');
        for(const [key,value] of Object.entries({in:'SourceGraphic',in2:'lens',scale:'14',xChannelSelector:'R',yChannelSelector:'G'}))displacement.setAttribute(key,value);
        filter.append(image,displacement);defs.append(filter);entry={filter,image,id};maps.set(node,entry);
        node.style.setProperty('--glass-lens',`url("#${id}")`);node.classList.add('custom-liquid-glass');
      }
      entry.w=w;entry.h=h;entry.radius=radius;
      const canvas=document.createElement('canvas'),ratio=Math.min(2,640/w,Math.sqrt(98000/(w*h)));
      canvas.width=Math.ceil(w*ratio);canvas.height=Math.ceil(h*ratio);
      const context=canvas.getContext('2d'),pixels=context.createImageData(canvas.width,canvas.height);
      for(let y=0;y<canvas.height;y++)for(let x=0;x<canvas.width;x++){
        const [r,g]=glassDisplacement(w,h,(x+.5)/ratio,(y+.5)/ratio,radius),i=(y*canvas.width+x)*4;
        pixels.data[i]=r;pixels.data[i+1]=g;pixels.data[i+2]=128;pixels.data[i+3]=255;
      }
      context.putImageData(pixels,0,0);
      entry.image.setAttribute('href',canvas.toDataURL());
      for(const element of [entry.filter,entry.image]){element.setAttribute('width',w);element.setAttribute('height',h);element.setAttribute('x','0');element.setAttribute('y','0');}
    }
    const observer=new ResizeObserver(entries=>{
      for(const {target} of entries){
        const entry=maps.get(target);
        if(entry&&entry.w===target.clientWidth&&entry.h===target.clientHeight)continue;
        pending.add(target);target.classList.add('glass-in-motion');
      }
      if(!pending.size)return;
      // Rebuilding PNG displacement maps while AppKit is resizing blocks the
      // renderer. Use the light glass while dimensions move, rebuild once idle.
      clearTimeout(timer);timer=setTimeout(()=>{
        timer=null;for(const node of pending){update(node);node.classList.remove('glass-in-motion');}pending.clear();
      },180);
    });
    for(const node of nodes){update(node);observer.observe(node);node.addEventListener('pointermove',light);}
    return()=>{clearTimeout(timer);observer.disconnect();svg.remove();for(const node of nodes){node.removeEventListener('pointermove',light);node.classList.remove('custom-liquid-glass','glass-in-motion');for(const name of ['--glass-lens','--glass-light-x','--glass-light-y','--lens-radius'])node.style.removeProperty(name);}};
  },[style]);
}
