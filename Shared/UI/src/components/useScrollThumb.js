import {useEffect} from 'react';
import {mountScrollbar} from './scrollbar.js';
export function useScrollThumb(root,{input='keyboard-mouse',label='滚动内容'}={}){
 useEffect(()=>root.current?mountScrollbar(root.current,{input,label}):undefined,[root,input,label]);
}
