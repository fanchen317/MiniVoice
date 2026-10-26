import OwnDesktopLyrics,{DesktopLyricsUnlock} from './OwnDesktopLyrics';
import '../../../Shared/UI/src/components/foundation.css';
import {usePresentation} from '../../../Shared/UI/src/components/usePresentation.js';
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import {presentationFor} from '../../../Shared/UI/src/presentation.js';
import {springEasing} from './motion';
import './style.css';
import './restoration.css';
import './mainParity.css';
import './liquidGlass.css';
import './wallControls.css';
import './parityCompletion.css';
import './compactPopovers.css';
import './surfaceRefinement.css';
import './ownPanels.css';
import './wallDock.css';
import '../../../Shared/UI/src/components/materials.css';

for(const [name,response,damping] of [['chrome-spring',.42,.88],['float-hover',.32,.62],['float-press',.25,.8],['control-hover',.3,.62],['control-press',.22,.7],['search-spring',.36,.76],['poster-spring',.28,.8],['song-return',.3,.8]])document.documentElement.style.setProperty(`--${name}`,springEasing(response,damping));

// No StrictMode double-mount: subscriptions and the native engine each have one owner.
const root=createRoot(document.getElementById('root'));
// Desktop keeps the Mac presentation even in a narrow window or preview mode.
const presentation=presentationFor({platform:'macos',deviceClass:'desktop'});
document.documentElement.dataset.presentation=presentation.family;
document.documentElement.dataset.reference=presentation.reference;
const desktopRoot=()=>document.documentElement;
function DesktopApplication(){usePresentation(desktopRoot,presentation);return <App/>;}
const surface=new URLSearchParams(location.search).get('surface');root.render(surface==='desktopLyrics'?<OwnDesktopLyrics/>:surface==='desktopLyricsUnlock'?<DesktopLyricsUnlock/>:<DesktopApplication/>);
