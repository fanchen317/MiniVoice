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
    const rowHeight=fontSize*1.8;let x=0,row=0;
    glyphs=characters.map(word=>{
      const advance=Math.max(fontSize*.3,measure(word.text,fontSize))+fontSize*.12;
      if(x>0&&x+advance>width){row++;x=0;}
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

// A single phrase transform and a clipped ink pass: glyphs never spring independently.
export function paintKineticPhrase(ctx,characters,layout,time,width,height){
 if(!characters.length)return;
 const start=characters[0].start,end=Math.max(start+.1,characters.at(-1).end??start+4);
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
 const entry=smooth((time-start)/.42),release=1-smooth((time-end)/.6);
 // Accumulate nearby syllable onsets into one damped phrase envelope.
 let energy=0;
 for(const char of characters){const age=time-char.start;if(age>=0&&age<.8)energy+=Math.exp(-age*7)*Math.sin(Math.min(1,age/.12)*Math.PI/2);}
 energy=Math.tanh(energy*.35)*release;
 const scale=.985+.015*entry+.018*energy,y=(1-entry)*height*.035-energy*layout.fontSize*.045;
 ctx.save();ctx.translate(width/2,height/2+y);ctx.scale(scale,scale);ctx.translate(-width/2,-height/2);
 ctx.font=`700 ${layout.fontSize}px system-ui,sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';
 characters.forEach((char,i)=>{
  const point=layout.glyphs[i],advance=ctx.measureText(char.text).width;
  ctx.globalAlpha=.48+.12*entry;ctx.fillStyle='#fff';ctx.fillText(char.text,point.x,point.y);
  const fill=progress(time,char.start,char.end??char.start+.3);
  if(fill<=0)return;
  ctx.save();ctx.beginPath();ctx.rect(point.x-advance/2-1,point.y-layout.fontSize, (advance+2)*fill,layout.fontSize*2);ctx.clip();
  ctx.globalAlpha=1;ctx.fillStyle='#fff';ctx.fillText(char.text,point.x,point.y);ctx.restore();
 });
 ctx.restore();
}
