import React from 'react';
import { X } from 'lucide-react';

const Modal = ({ isOpen, onClose, title, children, size = 'md' }) => {
  if (!isOpen) return null;

  const sizeClasses = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl'
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 modal-backdrop"
        onClick={onClose}
      />
      <div
        className={`relative bg-dark-card border border-dark-border rounded-xl shadow-2xl w-full ${sizeClasses[size]} max-h-[90vh] overflow-hidden animate-fadeIn`}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-dark-border">
          <h2 className="text-lg font-semibold text-white">{title}</h2>
          <button
            onClick={onClose}
            className="p-1 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 overflow-y-auto max-h-[calc(90vh-60px)]">
          {children}
        </div>
      </div>
    </div>
  );
};

export default Modal;
