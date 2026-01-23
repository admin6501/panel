import React, { useState } from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
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
  Bot
} from 'lucide-react';

const Layout = () => {
  const { user, logout } = useAuth();
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
    <div className="min-h-screen bg-[#020617]">
      {/* Mobile Header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 h-16 bg-[#0f172a] border-b border-[#1e293b] z-50 flex items-center justify-between px-4">
        <button
          onClick={() => setSidebarOpen(!sidebarOpen)}
          className="p-2 text-slate-400 hover:text-white"
          data-testid="mobile-menu-btn"
        >
          {sidebarOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
        <div className="flex items-center gap-2">
          <Bot className="text-blue-500" size={24} />
          <span className="font-bold text-white">V2Ray Bot</span>
        </div>
        <div className="w-10" />
      </div>

      {/* Sidebar */}
      <aside
        className={`fixed top-0 right-0 h-full w-64 bg-[#0f172a] border-l border-[#1e293b] z-40 transform transition-transform duration-300 lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'
        }`}
      >
        {/* Logo */}
        <div className="h-16 flex items-center gap-3 px-4 border-b border-[#1e293b]">
          <Bot className="text-blue-500" size={28} />
          <div>
            <h1 className="font-bold text-white">V2Ray Bot</h1>
            <p className="text-xs text-slate-500">پنل مدیریت</p>
          </div>
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
                    ? 'bg-blue-500/10 text-blue-500 border border-blue-500/20'
                    : 'text-slate-400 hover:bg-[#1e293b] hover:text-white'
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
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-[#1e293b]">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-white">{user?.username}</p>
              <p className="text-xs text-slate-500">{user?.role === 'super_admin' ? 'مدیر کل' : 'ادمین'}</p>
            </div>
            <button
              onClick={handleLogout}
              className="p-2 text-slate-400 hover:text-red-500 transition-colors"
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
