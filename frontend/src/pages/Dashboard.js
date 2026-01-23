import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  Users,
  ShoppingCart,
  CreditCard,
  MessageSquare,
  TrendingUp,
  Package,
  UserCheck,
  Clock
} from 'lucide-react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar
} from 'recharts';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const StatCard = ({ icon: Icon, label, value, color, subValue }) => (
  <div className="stat-card animate-fadeIn">
    <div className="flex items-start justify-between">
      <div>
        <p className="stat-label">{label}</p>
        <p className="stat-value mt-1" style={{ color }}>{value}</p>
        {subValue && (
          <p className="text-xs text-slate-500 mt-1">{subValue}</p>
        )}
      </div>
      <div
        className="p-3 rounded-lg"
        style={{ backgroundColor: `${color}15` }}
      >
        <Icon size={22} style={{ color }} />
      </div>
    </div>
  </div>
);

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [statsRes, chartRes] = await Promise.all([
        axios.get(`${API_URL}/api/dashboard/stats`),
        axios.get(`${API_URL}/api/dashboard/chart?days=7`)
      ]);
      setStats(statsRes.data);
      setChartData(chartRes.data);
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="spinner"></div>
      </div>
    );
  }

  const statCards = [
    {
      icon: Users,
      label: 'کل کاربران',
      value: stats?.total_users || 0,
      color: '#3b82f6',
      subValue: `+${stats?.today_users || 0} امروز`
    },
    {
      icon: ShoppingCart,
      label: 'کل سفارشات',
      value: stats?.total_orders || 0,
      color: '#10b981',
      subValue: `+${stats?.today_orders || 0} امروز`
    },
    {
      icon: TrendingUp,
      label: 'کل درآمد',
      value: formatPrice(stats?.total_revenue || 0),
      color: '#f59e0b',
      subValue: `${formatPrice(stats?.today_revenue || 0)} امروز`
    },
    {
      icon: CreditCard,
      label: 'پرداخت‌های معلق',
      value: stats?.pending_payments || 0,
      color: '#ef4444'
    },
    {
      icon: Package,
      label: 'اشتراک‌های فعال',
      value: stats?.active_subscriptions || 0,
      color: '#8b5cf6'
    },
    {
      icon: MessageSquare,
      label: 'تیکت‌های باز',
      value: stats?.open_tickets || 0,
      color: '#06b6d4'
    },
    {
      icon: UserCheck,
      label: 'نمایندگان',
      value: stats?.total_resellers || 0,
      color: '#ec4899'
    },
    {
      icon: Clock,
      label: 'امروز',
      value: new Date().toLocaleDateString('fa-IR'),
      color: '#64748b'
    }
  ];

  return (
    <div className="space-y-6" data-testid="dashboard">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">داشبورد</h1>
          <p className="text-slate-400 text-sm mt-1">خلاصه وضعیت سیستم</p>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((card, index) => (
          <StatCard key={index} {...card} />
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Revenue Chart */}
        <div className="chart-container">
          <h3 className="text-lg font-semibold text-white mb-4">نمودار درآمد (۷ روز اخیر)</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis
                dataKey="date"
                stroke="#64748b"
                tick={{ fill: '#64748b', fontSize: 12 }}
              />
              <YAxis
                stroke="#64748b"
                tick={{ fill: '#64748b', fontSize: 12 }}
                tickFormatter={(value) => `${(value / 1000).toFixed(0)}k`}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#0f172a',
                  border: '1px solid #1e293b',
                  borderRadius: '8px',
                  color: '#f8fafc'
                }}
                formatter={(value) => [formatPrice(value), 'درآمد']}
              />
              <Line
                type="monotone"
                dataKey="revenue"
                stroke="#3b82f6"
                strokeWidth={2}
                dot={{ fill: '#3b82f6', strokeWidth: 2 }}
                activeDot={{ r: 6, fill: '#3b82f6' }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Orders Chart */}
        <div className="chart-container">
          <h3 className="text-lg font-semibold text-white mb-4">نمودار سفارشات (۷ روز اخیر)</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis
                dataKey="date"
                stroke="#64748b"
                tick={{ fill: '#64748b', fontSize: 12 }}
              />
              <YAxis
                stroke="#64748b"
                tick={{ fill: '#64748b', fontSize: 12 }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#0f172a',
                  border: '1px solid #1e293b',
                  borderRadius: '8px',
                  color: '#f8fafc'
                }}
              />
              <Bar dataKey="orders" fill="#10b981" radius={[4, 4, 0, 0]} />
              <Bar dataKey="users" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
