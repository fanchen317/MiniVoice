const positive=(value,fallback)=>Number.isFinite(value)&&value>0?value:fallback;
const clamp=value=>Math.max(0,Math.min(1,value));
/** Final background surface, in CSS pixels. Device pixels guide analysis quality,
 * never replace the application's actual visible aspect with screen.width. */
export function artworkViewport({width,height,displayWidth=width,displayHeight=height,pixelRatio=globalThis.devicePixelRatio||1,occlusions=[]}={}){
 width=positive(width,1);height=positive(height,1);displayWidth=positive(displayWidth,width);displayHeight=positive(displayHeight,height);pixelRatio=Math.min(4,positive(pixelRatio,1));
 const normalized=occlusions.filter(box=>[box.x,box.y,box.width,box.height].every(Number.isFinite)&&box.width>0&&box.height>0).map(box=>{const x=clamp(box.x),y=clamp(box.y),right=clamp(box.x+box.width),bottom=clamp(box.y+box.height);return {x,y,width:Math.max(0,right-x),height:Math.max(0,bottom-y),weight:Math.max(0,Math.min(1,Number.isFinite(box.weight)?box.weight:.5))};}).filter(box=>box.width>0&&box.height>0).slice(0,24);
 return {width,height,displayWidth,displayHeight,pixelWidth:Math.round(displayWidth*pixelRatio),pixelHeight:Math.round(displayHeight*pixelRatio),pixelRatio,occlusions:normalized};
}
const defaultSelectors=[
 {selector:'.wall-card-content > header h2, .wall-card-content > header p, .wp-heading h1, .wp-heading p',text:true,weight:.8},
 {selector:'.wall-card-content .wall-playback-status, .wp-status',weight:.5},
 {selector:'.wall-card-transport, .wp-footer',weight:.7},
 {selector:'.wall-lyrics, .wp-lyrics, .mv-kinetic-lyrics',weight:.2},
];
/** Normalize live UI rectangles by their common transformed root: this cancels
 * a parent's FLIP scale/translation. Text ranges exclude empty block width.
 * Called at layout/target changes, never on lyric-clock or animation ticks. */
export function measureArtworkViewport(root,target,{selectors=defaultSelectors}={}){
 const result=artworkViewport(target);if(!root?.getBoundingClientRect)return result;
 const bounds=root.getBoundingClientRect();if(!(bounds.width>0&&bounds.height>0))return result;
 const boxes=[];
 for(const entry of selectors){for(const node of root.querySelectorAll(entry.selector)){
  const style=globalThis.getComputedStyle?.(node);if(style&&(style.display==='none'||style.visibility==='hidden'))continue;
  let rect=node.getBoundingClientRect();
  if(entry.text&&node.ownerDocument?.createRange){const range=node.ownerDocument.createRange();range.selectNodeContents(node);const text=range.getBoundingClientRect();if(text.width>0&&text.height>0)rect=text;range.detach?.();}
  // Lyric rows can exist outside their masked scroll viewport. Intersect
  // clipping ancestors before treating their text as a visible obstruction.
  let left=rect.left,top=rect.top,right=rect.left+rect.width,bottom=rect.top+rect.height;
  for(let parent=node.parentElement;parent&&parent!==root;parent=parent.parentElement){const clip=globalThis.getComputedStyle?.(parent);if(!clip)continue;const x=/(hidden|clip|scroll|auto)/.test(clip.overflowX),y=/(hidden|clip|scroll|auto)/.test(clip.overflowY);if(x||y){const r=parent.getBoundingClientRect();if(x){left=Math.max(left,r.left);right=Math.min(right,r.left+r.width);}if(y){top=Math.max(top,r.top);bottom=Math.min(bottom,r.top+r.height);}}}
  left=Math.max(left,bounds.left);top=Math.max(top,bounds.top);right=Math.min(right,bounds.left+bounds.width);bottom=Math.min(bottom,bounds.top+bounds.height);
  rect={left,top,width:Math.max(0,right-left),height:Math.max(0,bottom-top)};
  if(rect.width<=0||rect.height<=0)continue;
  boxes.push({x:(rect.left-bounds.left)/bounds.width,y:(rect.top-bounds.top)/bounds.height,width:rect.width/bounds.width,height:rect.height/bounds.height,weight:entry.weight});
 }}
 return artworkViewport({...result,occlusions:boxes});
}
