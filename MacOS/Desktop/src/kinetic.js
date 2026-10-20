// Presentation estimates follow LyricsDisplayTiming; source lyrics remain untouched.
export function displayLine(line,nextStart,duration){
  if(line.words?.length||!Number.isFinite(line.time)||line.time<0||!line.text?.trim())return line;
  const characters=[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(line.text)].map(part=>part.segment),start=line.time;
  const bounds=[line.end,nextStart,duration].filter(value=>Number.isFinite(value)&&value>start),nearest=bounds.length?Math.min(...bounds):null;
  let end=nearest!==null&&nearest-start<=12?nearest:start+Math.min(10,Math.max(2,characters.length*.28));
  if(Number.isFinite(nextStart)&&nextStart>start)end=Math.min(end,nextStart-Math.min(.3,(nextStart-start)*.12));
  const step=(end-start)/characters.length;
  return {...line,words:characters.map((text,index)=>({text,start:start+index*step,end:start+(index+1)*step}))};
}
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
  return {fontSize,glyphs:glyphs.map(point=>({...point,y:point.y+(size.height-totalHeight)/2}))};
}
const progress=(time,start,end)=>Math.min(1,Math.max(0,(time-start)/Math.max(.001,end-start)));
export function kineticInk(word,index,time,fontSize){
  const entrance=progress(time,word.start,word.start+.34),p=progress(time,word.start,Math.max(word.start+.24,word.end??word.start+.5));
  const pulse=time>=word.start?Math.max(0,Math.sin(p*Math.PI)):0,bounce=Math.sin(entrance*Math.PI)*(1-entrance)*fontSize*.19;
  return {opacity:time < word.start ? .26 : .82+.18*entrance,y:(1-entrance)*fontSize*.12-bounce-pulse*fontSize*.08,rotation:Math.sin(index*1.7)*3*Math.sin(entrance*Math.PI)*Math.PI/180,scale:.94+.06*entrance+.12*pulse,color:`rgb(${(1-.45*pulse)*255},${(1-.12*pulse)*255},255)`,shadow:pulse*.6,shadowRadius:10*pulse};
}
export function wallLyricsMetrics(width,height){
  const singleLine=height<60,fontSize=Math.min(58,Math.max(12,Math.min(width*.062,height/(singleLine?2.8:11))));
  const rowHeight=singleLine?height:Math.min(height/3,fontSize*2.15+8);
  return {singleLine,fontSize,rowHeight,visibleRadius:singleLine?0:Math.max(4,Math.ceil(height/Math.max(1,rowHeight)))};
}
export function wallCardSizing(width,height){
  const scale=Math.min(1,Math.max(.65,Math.min(width/430,height/430)));
  return {title:Math.max(16,28*scale),artist:Math.max(10,14*scale),status:Math.max(9,11*scale),spacing:12*scale,padding:Math.max(12,22*scale)};
}
