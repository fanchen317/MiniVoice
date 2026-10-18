import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import {springEasing} from './motion';
import './style.css';
import './restoration.css';
import './mainParity.css';
import './liquidGlass.css';
import './wallControls.css';
import './parityCompletion.css';

for(const [name,response,damping] of [['chrome-spring',.42,.88],['float-hover',.32,.62],['float-press',.25,.8],['control-hover',.3,.62],['control-press',.22,.7],['search-spring',.36,.76],['poster-spring',.28,.8],['song-return',.3,.8]])document.documentElement.style.setProperty(`--${name}`,springEasing(response,damping));

// No StrictMode double-mount: subscriptions and the native engine each have one owner.
createRoot(document.getElementById('root')).render(<App/>);
