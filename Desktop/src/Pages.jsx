import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { artwork } from './store';
import { Cover, GroupGrid, Icon, IconButton, Lyrics, TranslationToggle } from './components';
import { fadeHeroOut, reducedMotion, springLayout } from './transitions';
import { playerDetailMetrics } from './motion';

export function Backdrop({track}){
  const url=artwork(track),[layers,setLayers]=useState([]);
  const colors=track?.backdropColors||[[.90,.97,.98],[.94,.99,.97]];
  const gradient=`linear-gradient(to bottom right,${colors.map(rgb=>`rgb(${rgb.map(value=>Math.round(value*255)).join(' ')})`).join(',')})`;
  useEffect(()=>{
    let live=true,timer;
    if(!url){setLayers([]);return;}
    const image=new Image();image.src=url;
    image.decode().then(()=>{if(live){setLayers(previous=>[...previous.slice(-1),url]);timer=setTimeout(()=>live&&setLayers([url]),500);}}).catch(()=>{});
    return()=>{live=false;clearTimeout(timer);};
  },[url]);
  return <div className="cover-backdrop" aria-hidden="true"><div className="cover-palette" style={{background:gradient}}/>{layers.map((src,index)=><img src={src} key={src} alt=""/>)}</div>;
}
export function NavigationSelection({value}){
  const marker=useRef();
  useLayoutEffect(()=>{
    const parent=marker.current.parentElement,button=parent.querySelector('button.active');
    if(button){marker.current.style.height=`${button.offsetHeight}px`;marker.current.style.transform=`translateY(${button.offsetTop}px)`;}
  },[value]);
  return <span ref={marker} className="navigation-selection" aria-hidden="true"/>;
}
export function SimplePage({sizing,track,playbackTrack,expanded,onExpanded,onEdit}){
  const root=useRef(),previousExpanded=useRef(expanded),metrics=playerDetailMetrics(sizing);

  useLayoutEffect(()=>{
    const title=root.current.querySelector('.simple-hero h1');
    const fit=()=>{
      title.style.fontSize='';const base=metrics.titleSize;let low=.85,high=1;
      for(let i=0;i<7;i++){const scale=(low+high)/2;title.style.fontSize=`${base*scale}px`;if(title.scrollHeight>parseFloat(getComputedStyle(title).lineHeight)*2+1)high=scale;else low=scale;}
      title.style.fontSize=`${base*(high>.99?1:low)}px`;
    };
    fit();const observer=new ResizeObserver(fit);observer.observe(root.current);return()=>observer.disconnect();
  },[track?.title,metrics.titleSize]);
  useLayoutEffect(()=>{if(previousExpanded.current&&!expanded&&!reducedMotion())root.current.querySelector('.simple-hero').animate([{opacity:0,transform:'scale(.94)'},{opacity:1,transform:'none'}],{duration:460,easing:'ease-out'});previousExpanded.current=expanded;},[expanded]);
  function toggle(){if(!expanded)fadeHeroOut();springLayout(()=>onExpanded(!expanded),'.simple-lyrics',.46,.9);}
  return <section ref={root} className={`simple-player ${expanded?'lyrics-expanded':''}`} style={{'--hero-size':`${metrics.artworkSize}px`,'--hero-title-size':`${metrics.titleSize}px`,'--hero-text-gap':metrics.artworkSize<160?'6px':'12px','--hero-album-lines':metrics.artworkSize<160?1:2}}>
    <div className="simple-hero-slot" aria-hidden={expanded} inert={expanded}>
      <div className="simple-hero"><div className="simple-art"><Cover track={track} detail/></div><div><h1>{track?.title||'选择一首音乐'}</h1><h3>{track?.artist}</h3><p>{track?.album}</p></div></div>
    </div>

    <section className="simple-lyrics" aria-label="歌词"><header><span className="lyrics-header-actions"><TranslationToggle track={playbackTrack}/><IconButton label={expanded?'收起歌词':'展开歌词'} active={expanded} onClick={toggle}><span className={`expand-symbol ${expanded?'is-expanded':''}`}><Icon name="expand"/><Icon name="collapse"/></span></IconButton></span></header><Lyrics track={playbackTrack} expanded={expanded} onEdit={()=>playbackTrack&&onEdit(playbackTrack)}/></section>
  </section>;
}

// Keep the card grid and its scroll position alive until the detail has returned
// to its source. Scrolling the detail never changes the source card's position.
export function BrowsePages({groups,artist,selected,onOpen,onClose,toolbar,children}){
  const root=useRef(),panel=useRef(),origin=useRef(null),animation=useRef(),epoch=useRef(0),[closing,setClosing]=useState(false);
  function open(group,event){
    const card=event.currentTarget.getBoundingClientRect(),bounds=root.current.getBoundingClientRect();
    origin.current={x:card.x-bounds.x,y:card.y-bounds.y,width:card.width,height:card.height};onOpen(group);
  }
  useLayoutEffect(()=>{
    if(!selected||!panel.current)return;
    setClosing(false);
    if(reducedMotion()||!origin.current)return;
    const from=origin.current,to=panel.current.getBoundingClientRect();
    animation.current=panel.current.animate([{transform:`translate(${from.x}px,${from.y}px) scale(${from.width/to.width},${from.height/to.height})`,opacity:.3,borderRadius:'12px'},{transform:'none',opacity:1,borderRadius:'16px'}],{duration:240,easing:'ease-in-out'});
    return()=>animation.current?.cancel();
  },[selected]);
  useEffect(()=>()=>{epoch.current++;animation.current?.cancel();},[]);
  async function close(){
    if(closing)return;const generation=epoch.current;setClosing(true);
    if(!reducedMotion()&&panel.current&&origin.current){
      animation.current?.cancel();const from=origin.current,to=panel.current.getBoundingClientRect();
      animation.current=panel.current.animate([{transform:'none',opacity:1},{transform:`translate(${from.x}px,${from.y}px) scale(${from.width/to.width},${from.height/to.height})`,opacity:0}],{duration:240,easing:'ease-in-out',fill:'forwards'});
      await animation.current.finished.catch(()=>{});
    }
    if(generation===epoch.current&&root.current?.isConnected){onClose();setClosing(false);}
  }
  useEffect(()=>{const key=event=>{if(event.key==='Escape'&&selected)close();};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key);},[selected,closing]);
  return <div ref={root} className={`browse-pages ${selected?'detail-open':''}`}>
    <div className="browse-card-home songs-panel" inert={Boolean(selected)} aria-hidden={Boolean(selected)}>{toolbar}<GroupGrid groups={groups} artist={artist} onOpen={open}/></div>
    {selected&&<section ref={panel} className="browse-card-detail">{typeof children==='function'?children(close):children}</section>}
  </div>;
}
