/** Product family is selected by the host, never inferred from viewport width. */
export function presentationFor({platform,deviceClass}={}){
 const desktop=deviceClass==='desktop'||(!deviceClass&&['macos','windows','linux'].includes(platform));
 return Object.freeze({family:desktop?'desktop':'mobile',reference:desktop?'mac':'android',navigation:desktop?'sidebar':'drawer',contextMenu:desktop?'popover':'sheet',primaryInput:desktop?'keyboard-mouse':'touch'});
}
/** Layout changes within a family. A wide tablet is still a touch application. */
export function layoutFor(presentation,{width=0,height=0}={}){
 const landscape=width>height,wide=width>=800,tablet=Math.min(width,height)>=600;
 return Object.freeze({family:presentation.family,input:presentation.primaryInput,orientation:landscape?'landscape':'portrait',size:wide?'wide':'compact',device:presentation.family==='desktop'?'computer':tablet?'tablet':'phone',minimumTarget:presentation.family==='mobile'?44:28,dialog:presentation.family==='desktop'?'center':tablet?'center':'bottom'});
}
