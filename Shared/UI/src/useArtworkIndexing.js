import {useEffect,useMemo} from 'react';
import {createArtworkIndexer} from './artworkIndexing.js';
import {precomputeArtworkSubjects} from './artworkSubjectDetector.js';

// Index only while the app is visible and the user is idle. Focused requests
// still use the shared newest-first inference queue.
export function useArtworkIndexing(items){
 const indexer=useMemo(()=>createArtworkIndexer({run:precomputeArtworkSubjects,isVisible:()=>!document.hidden,interval:3500}),[]);
 useEffect(()=>{
  let lastMove=0;
  const activity=()=>{lastMove=performance.now();indexer.activity();};
  const moveActivity=()=>{const now=performance.now();if(now-lastMove>=240){lastMove=now;indexer.activity();}};
  const visibility=()=>indexer.visibilityChanged(),cleared=()=>indexer.clear(),inspect=()=>indexer.refresh();
  for(const name of ['pointerdown','touchstart','keydown','wheel','click','minivoice-activity'])window.addEventListener(name,activity,{passive:true,capture:true});
  for(const name of ['pointermove','touchmove','scroll'])window.addEventListener(name,moveActivity,{passive:true,capture:true});
  document.addEventListener('visibilitychange',visibility);window.addEventListener('minivoice-artwork-cache-cleared',cleared);window.addEventListener('minivoice-library-inspection',inspect);
  return()=>{
   for(const name of ['pointerdown','touchstart','keydown','wheel','click','minivoice-activity'])window.removeEventListener(name,activity,{capture:true});
   for(const name of ['pointermove','touchmove','scroll'])window.removeEventListener(name,moveActivity,{capture:true});
   document.removeEventListener('visibilitychange',visibility);window.removeEventListener('minivoice-artwork-cache-cleared',cleared);window.removeEventListener('minivoice-library-inspection',inspect);indexer.dispose();
  };
 },[indexer]);
 useEffect(()=>indexer.update(items),[indexer,items]);
}
