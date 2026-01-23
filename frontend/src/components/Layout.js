import React, { useState } from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useTheme } from '../contexts/ThemeContext';
import {
  LayoutDashboard,
  Users,
  Server,
  Package,
  ShoppingCart,
  CreditCard,
  Tag,
  MessageSquare,
  UserCheck,
  Settings,
  LogOut,
  Menu,
  X,
  Bot,
  Sun,
  Moon
} from 'lucide-react';

const Layout = () => {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: 'داشبورد' },
    { path: '/users', icon: Users, label: 'کاربران' },
    { path: '/servers', icon: Server, label: 'سرورها' },
    { path: '/plans', icon: Package, label: 'پلن‌ها' },
    { path: '/orders', icon: ShoppingCart, label: 'سفارشات' },
    { path: '/payments', icon: CreditCard, label: 'پرداخت‌ها' },
    { path: '/discount-codes', icon: Tag, label: 'کدهای تخفیف' },
    { path: '/tickets', icon: MessageSquare, label: 'تیکت‌ها' },
    { path: '/resellers', icon: UserCheck, label: 'نمایندگان' },
    { path: '/settings', icon: Settings, label: 'تنظیمات' },
  ];

  return (
    <div className="min-h-screen bg-background">
      {/* Mobile Header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 h-16 bg-card border-b border-border z-50 flex items-center justify-between px-4">
        <button
          onClick={() => setSidebarOpen(!sidebarOpen)}
          className="p-2 text-muted-foreground hover:text-foreground"
          data-testid="mobile-menu-btn"
        >
          {sidebarOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
        <div className="flex items-center gap-2">
          <Bot className="text-primary" size={24} />
          <span className="font-bold text-foreground">V2Ray Bot</span>
        </div>
        <button
          onClick={toggleTheme}
          className="theme-toggle"
          data-testid="mobile-theme-toggle"
        >
          {theme === 'dark' ? <Sun size={20} /> : <Moon size={20} />}
        </button>
      </div>

      {/* Sidebar */}
      <aside
        className={`fixed top-0 right-0 h-full w-64 bg-card border-l border-border z-40 transform transition-transform duration-300 lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'
        }`}
      >
        {/* Logo */}
        <div className="h-16 flex items-center justify-between px-4 border-b border-border">
          <div className="flex items-center gap-3">
            <Bot className="text-primary" size={28} />
            <div>
              <h1 className="font-bold text-foreground">V2Ray Bot</h1>
              <p className="text-xs text-muted-foreground">پنل مدیریت</p>
            </div>
          </div>
          <button
            onClick={toggleTheme}
            className="theme-toggle hidden lg:flex"
            data-testid="theme-toggle"
            title={theme === 'dark' ? 'تم روشن' : 'تم تاریک'}
          >
            {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
          </button>
        </div>

        {/* Navigation */}
        <nav className="p-3 space-y-1">
          {menuItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 ${
                  isActive
                    ? 'bg-primary/10 text-primary border border-primary/20'
                    : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                }`
              }
              data-testid={`nav-${item.path.replace('/', '') || 'dashboard'}`}
            >
              <item.icon size={20} />
              <span className="font-medium">{item.label}</span>
            </NavLink>
          ))}
        </nav>

        {/* User Info */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-border">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-foreground">{user?.username}</p>
              <p className="text-xs text-muted-foreground">{user?.role === 'super_admin' ? 'مدیر کل' : 'ادمین'}</p>
            </div>
            <button
              onClick={handleLogout}
              className="p-2 text-muted-foreground hover:text-destructive transition-colors"
              data-testid="logout-btn"
            >
              <LogOut size={20} />
            </button>
          </div>
        </div>
      </aside>

      {/* Overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-30 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main Content */}
      <main className="lg:mr-64 pt-16 lg:pt-0 min-h-screen">
        <div className="p-4 lg:p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default Layout;
