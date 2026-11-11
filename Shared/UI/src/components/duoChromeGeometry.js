// Localized system cutouts do not reserve a full-height column on the inner display.
export function duoChromeGeometry(width,height,occlusions=[],topInset=0){
 const side=56,gap=14,overlap=(a,b)=>a.x<b.x+b.width&&a.x+a.width>b.x&&a.y<b.y+b.height&&a.y+a.height>b.y;
 const fit=box=>{let r={...box};for(const o of occlusions){if(!overlap(r,o))continue;const candidates=[{...r,x:o.x-gap-side},{...r,x:o.x+o.width+gap},{...r,y:o.y-gap-side},{...r,y:o.y+o.height+gap}].filter(c=>c.x>=gap&&c.y>=topInset+gap&&c.x+side<=width-gap&&c.y+side<=height-gap&&!occlusions.some(o=>overlap(c,o)));candidates.sort((a,b)=>Math.hypot(a.x-box.x,a.y-box.y)-Math.hypot(b.x-box.x,b.y-box.y));if(candidates[0])r=candidates[0];}return r;};
 const menu=fit({x:gap,y:topInset+gap,width:side,height:side}),search=fit({x:width-gap-side,y:topInset+gap,width:side,height:side}),dock=fit({x:gap,y:height-gap-side,width:side,height:side}),settings=fit({x:width-gap-side,y:height-gap-side,width:side,height:side});
 const rowBottom=Math.min(dock.y,settings.y);dock.y=rowBottom;settings.y=rowBottom;
 const rowTop=Math.max(menu.y,search.y);menu.y=rowTop;search.y=rowTop;
 // Search and settings form one trailing column. Avoid the system cutout
 // with that column without reducing the canvas or moving the centered dock.
 const trailingX=Math.min(search.x,settings.x);
 const alignedSearch={...search,x:trailingX},alignedSettings={...settings,x:trailingX};
 if(!occlusions.some(o=>overlap(alignedSearch,o)||overlap(alignedSettings,o))){search.x=trailingX;settings.x=trailingX;}
 return {menu,search,dock,settings};
}
