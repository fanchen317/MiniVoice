import {useEffect,useRef} from 'react';
import {bindDialog} from './dialogBoundary.js';
export function useDialogBoundary(root,{onClose,background,initialFocus='dialog'}={}){
 const close=useRef(onClose);close.current=onClose;
 useEffect(()=>bindDialog(root.current,{onClose:()=>close.current?.(),background:background?.(),initialFocus}),[root,initialFocus]);
}
