import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './ui/fonts';
import './ui/theme.css';
import { Desk } from './ui/desk/Desk';
import { Stage } from './ui/Stage';

const root = document.getElementById('root');
if (!root) throw new Error('#root not found');

createRoot(root).render(
  <StrictMode>
    <Stage>
      <Desk />
    </Stage>
  </StrictMode>,
);
