declare module 'lucide-react' {
  import * as React from 'react';

  export interface IconProps extends React.SVGAttributes<SVGElement> {
    size?: number | string;
    color?: string;
  }

  export const MessageSquare: React.FC<IconProps>;
  export const Users: React.FC<IconProps>;
  export const LogOut: React.FC<IconProps>;
  export const Plus: React.FC<IconProps>;
  
  // Add other exports as needed
} 