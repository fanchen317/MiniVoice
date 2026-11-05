// Presentation estimates follow LyricsDisplayTiming; source lyrics remain untouched.
export {displayLine,wallLyricsMetrics} from './lyricPresentation.js';
export function kineticCharacters(line,nextStart){
  const segmenter=new Intl.Segmenter('zh',{granularity:'grapheme'});
  return (line.words||[]).flatMap((word,index,words)=>{
    const characters=[...segmenter.segment(word.text)].map(part=>part.segment);
    const end=word.end??words[index+1]?.start??line.end??nextStart??word.start+.5;
    const step=Math.max(0,end-word.start)/Math.max(1,characters.length);
    return characters.map((text,i)=>({text,start:word.start+i*step,end:word.start+(i+1)*step}));
  });
}
export function kineticLayout(characters,size,measure){
  const width=Math.max(1,size.width-32),height=Math.max(1,size.height-32);
  let fontSize=Math.min(58,Math.max(20,size.width*.095)),glyphs=[],totalHeight=0;
  for(let attempt=0;attempt<24;attempt++){
    const rowHeight=fontSize*1.65;
    const advances=characters.map(word=>Math.max(fontSize*.3,measure(word.text,fontSize))+fontSize*.12);
    const total=advances.reduce((a,b)=>a+b,0),rowCount=Math.max(1,Math.ceil(total/width));
    const rowWidth=Math.min(width,total/rowCount+Math.max(...advances,0)*.45);
    let x=0,row=0;
    glyphs=characters.map(word=>{
      const advance=Math.max(fontSize*.3,measure(word.text,fontSize))+fontSize*.12;
      if(x>0&&x+advance>rowWidth){row++;x=0;}
      const point={x:16+x+advance/2,y:row*rowHeight+rowHeight/2};x+=advance;return point;
    });
    totalHeight=(row+1)*rowHeight;if(totalHeight<=height||attempt===23)break;fontSize*=.82;
  }
  const rows=new Map();glyphs.forEach((point,i)=>{const key=point.y;if(!rows.has(key))rows.set(key,[]);rows.get(key).push(i);});
  for(const indices of rows.values()){const last=indices.at(-1),edge=glyphs[last].x+Math.max(fontSize*.3,measure(characters[last].text,fontSize))/2;const shift=(size.width-16-edge)/2;indices.forEach(i=>glyphs[i].x+=Math.max(0,shift));}
  return {fontSize,glyphs:glyphs.map(point=>({...point,y:point.y+(size.height-totalHeight)/2}))};
}
const progress=(time,start,end)=>Math.min(1,Math.max(0,(time-start)/Math.max(.001,end-start)));
// One phrase envelope keeps the baseline coherent; timing controls cadence, never
// a separate entrance spring for each glyph. Pure playback-time sampling is seekable.
export function kineticInk(word,index,time,fontSize,characters=[word]){
  const first=characters[0],last=characters[characters.length-1];
  const start=first.start,end=Math.max(start+.25,last.end??last.start+.5);
  const span=end-start,local=time-start;
  const envelope=Math.sin(progress(time,start,end)*Math.PI);
  const cadence=Math.min(2.2,Math.max(.55,characters.length/span/3));
  const phase=local*cadence*Math.PI*2;
  const center=(word.start+(word.end??word.start+.3))/2;
  const focus=Math.exp(-Math.pow((time-center)/.42,2))*envelope;
  const wave=Math.sin(phase-index*.10)*envelope;
  const sung=progress(time,word.start,word.start+.22);
  return {opacity:time<word.start?.46:.82+.18*sung,
    y:-fontSize*(.025*Math.sin(phase)*envelope+.012*wave+.014*focus),
    rotation:0,scale:1+.016*envelope*Math.sin(phase)+.018*focus,
    color:`rgb(${Math.round(255-42*focus)},${Math.round(255-12*focus)},255)`,
    shadow:focus*.28,shadowRadius:6*focus};
}
export function wallCardSizing(width,height){
  const scale=Math.min(1,Math.max(.65,Math.min(width/430,height/430)));
  return {title:Math.max(16,28*scale),artist:Math.max(10,14*scale),status:Math.max(9,11*scale),spacing:12*scale,padding:Math.max(12,22*scale)};
}

// A continuous singing cursor drives a wide spatial wave, rather than per-letter springs.
export function kineticWave(characters,time,index,fontSize){
 if(!characters.length)return {y:0,scale:1,rotation:0,glow:0};
 const smooth=value=>{const x=Math.max(0,Math.min(1,value));return x*x*(3-2*x);};
 let cursor=-.5;
 for(let i=0;i<characters.length;i++){
  const char=characters[i],next=characters[i+1];
  if(time<char.start)break;
  const end=Math.max(char.start+.001,next?.start??char.end??char.start+.5);
  cursor=i-.5+smooth((time-char.start)/(end-char.start));
 }
 const first=characters[0],last=characters.at(-1),end=last.end??last.start+.5;
 const envelope=smooth((time-first.start+.18)/.38)*(1-smooth((time-end)/.65));
 const distance=index-cursor;
 // Wide support couples neighbors. The trailing trough makes a rolling ribbon.
 const crest=Math.exp(-distance*distance/3.8);
 const trough=Math.exp(-Math.pow(distance+2.2,2)/5.5);
 const wave=(crest-.34*trough)*envelope;
 return {y:-fontSize*.17*wave,scale:1+.15*crest*envelope,
  rotation:Math.max(-1,Math.min(1,distance))*.018*crest*envelope,glow:crest*envelope};
}
export function paintKineticPhrase(ctx,characters,layout,time,width,height){
 if(!characters.length)return;
 ctx.save();
 ctx.font=`700 ${layout.fontSize}px system-ui,sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';
 characters.forEach((char,i)=>{
  const point=layout.glyphs[i],advance=ctx.measureText(char.text).width;
  const wave=kineticWave(characters,time,i,layout.fontSize);
  ctx.save();ctx.translate(point.x,point.y+wave.y);ctx.rotate(wave.rotation);ctx.scale(wave.scale,wave.scale);
  ctx.globalAlpha=.62;ctx.fillStyle='#dce7f4';ctx.fillText(char.text,0,0);
  const fill=progress(time,char.start,char.end??char.start+.3);
  if(fill>0){
   ctx.save();ctx.beginPath();ctx.rect(-advance/2-1,-layout.fontSize,(advance+2)*fill,layout.fontSize*2);ctx.clip();
   ctx.globalAlpha=1;
   const palette=kineticPalette(i,characters.length,time-characters[0].start);
   const gradient=ctx.createLinearGradient(-advance/2,-layout.fontSize*.5,advance/2,layout.fontSize*.5);
   gradient.addColorStop(0,palette.top);gradient.addColorStop(1,palette.bottom);
   ctx.fillStyle=gradient;ctx.shadowColor=palette.glow;ctx.shadowBlur=layout.fontSize*(.08+.2*wave.glow);
   ctx.fillText(char.text,0,0);ctx.restore();
  }
  ctx.restore();
 });
 ctx.restore();
}

// A bounded cyan / violet / rose ribbon, continuous in both space and playback time.
export function kineticPalette(index,count,elapsed){
 const phase=index/Math.max(1,count-1)*1.5+elapsed*.32;
 const hue=235+65*Math.sin(phase);
 return {top:`hsl(${hue-28},95%,82%)`,bottom:`hsl(${hue+18},92%,70%)`,glow:`hsla(${hue},95%,74%,0.65)`};
}
