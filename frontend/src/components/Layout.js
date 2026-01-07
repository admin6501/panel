import React, { useState } from 'react';
import { Outlet, Link, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import {
  LayoutDashboard,
  Users,
  Shield,
  Settings,
  LogOut,
  Menu,
  X,
  Globe,
  ChevronDown
} from 'lucide-react';

const Layout = () => {
  const { t, i18n } = useTranslation();
  const { user, logout, isSuperAdmin } = useAuth();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [langDropdown, setLangDropdown] = useState(false);

  const isRTL = i18n.language === 'fa';

  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: t('nav.dashboard') },
    { path: '/clients', icon: Shield, label: t('nav.clients') },
    ...(isSuperAdmin() ? [{ path: '/users', icon: Users, label: t('nav.users') }] : []),
    { path: '/settings', icon: Settings, label: t('nav.settings') },
  ];

  const changeLanguage = (lang) => {
    i18n.changeLanguage(lang);
    localStorage.setItem('language', lang);
    setLangDropdown(false);
  };

  const handleLogout = () => {
    logout();
  };

  return (
    <div className="flex h-screen">
      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed lg:static inset-y-0 ${isRTL ? 'right-0' : 'left-0'} z-50 w-64 bg-dark-card border-${isRTL ? 'l' : 'r'} border-dark-border transform transition-transform duration-300 lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : isRTL ? 'translate-x-full' : '-translate-x-full'
        }`}
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="p-6 border-b border-dark-border">
            <h1 className="text-xl font-bold text-white flex items-center gap-2">
              <Shield className="w-8 h-8 text-primary-500" />
              <span className="gradient-text">{t('app.title')}</span>
            </h1>
            <p className="text-dark-muted text-sm mt-1">{t('app.subtitle')}</p>
          </div>

          {/* Navigation */}
          <nav className="flex-1 p-4 space-y-2">
            {menuItems.map((item) => {
              const Icon = item.icon;
              const isActive = location.pathname === item.path;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setSidebarOpen(false)}
                  className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${
                    isActive
                      ? 'bg-primary-600 text-white'
                      : 'text-dark-muted hover:bg-dark-border hover:text-white'
                  }`}
                >
                  <Icon className="w-5 h-5" />
                  <span>{item.label}</span>
                </Link>
              );
            })}
          </nav>

          {/* User info & Logout */}
          <div className="p-4 border-t border-dark-border">
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-white font-medium">{user?.username}</p>
                <p className="text-dark-muted text-sm capitalize">
                  {user?.role?.replace('_', ' ')}
                </p>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 w-full px-4 py-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
            >
              <LogOut className="w-5 h-5" />
              <span>{t('nav.logout')}</span>
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-dark-card border-b border-dark-border px-4 lg:px-6 py-4">
          <div className="flex items-center justify-between">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="lg:hidden text-dark-text hover:text-white"
            >
              {sidebarOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>

            {/* Language Switcher */}
            <div className="relative mr-auto lg:mr-0">
              <button
                onClick={() => setLangDropdown(!langDropdown)}
                className="flex items-center gap-2 px-3 py-2 bg-dark-border rounded-lg text-dark-text hover:text-white transition-colors"
              >
                <Globe className="w-5 h-5" />
                <span>{i18n.language === 'fa' ? 'فارسی' : 'English'}</span>
                <ChevronDown className="w-4 h-4" />
              </button>

              {langDropdown && (
                <div className={`absolute ${isRTL ? 'left-0' : 'right-0'} mt-2 w-32 bg-dark-card border border-dark-border rounded-lg shadow-xl z-50`}>
                  <button
                    onClick={() => changeLanguage('fa')}
                    className={`w-full px-4 py-2 text-right hover:bg-dark-border transition-colors ${
                      i18n.language === 'fa' ? 'text-primary-500' : 'text-dark-text'
                    }`}
                  >
                    فارسی
                  </button>
                  <button
                    onClick={() => changeLanguage('en')}
                    className={`w-full px-4 py-2 text-right hover:bg-dark-border transition-colors ${
                      i18n.language === 'en' ? 'text-primary-500' : 'text-dark-text'
                    }`}
                  >
                    English
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default Layout;
