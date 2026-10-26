import {createContext,useContext} from 'react';
// The page injects the host callback. Components never import a platform bridge.
export const FeedbackContext=createContext(null);
export function useActivationFeedback(){return useContext(FeedbackContext);}

export function emitActivationFeedback(callback){try{callback?.()?.catch?.(()=>{});}catch{ /* Feedback cannot block the action. */ }}
