import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useTranslation } from 'react-i18next';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Clients from './pages/Clients';
import Users from './pages/Users';
import Settings from './pages/Settings';
import './App.css';

// Protected Route Component
const ProtectedRoute = ({ children, requiredRole }) => {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-dark-bg flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (requiredRole === 'super_admin' && user?.role !== 'super_admin') {
    return <Navigate to="/" replace />;
  }

  return children;
};

function AppContent() {
  const { i18n } = useTranslation();
  const isRTL = i18n.language === 'fa';

  React.useEffect(() => {
    document.documentElement.dir = isRTL ? 'rtl' : 'ltr';
    document.documentElement.lang = i18n.language;
  }, [i18n.language, isRTL]);

  return (
    <Router>
      <div className={`min-h-screen bg-dark-bg ${isRTL ? 'font-vazir' : 'font-inter'}`}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="clients" element={<Clients />} />
            <Route
              path="users"
              element={
                <ProtectedRoute requiredRole="super_admin">
                  <Users />
                </ProtectedRoute>
              }
            />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
        <Toaster
          position={isRTL ? 'top-left' : 'top-right'}
          toastOptions={{
            className: 'bg-dark-card text-dark-text border border-dark-border',
            duration: 4000,
          }}
        />
      </div>
    </Router>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
