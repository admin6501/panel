import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Users,
  UserCheck,
  UserX,
  Clock,
  Database,
  Wifi,
  Server,
  CheckCircle,
  XCircle
} from 'lucide-react';
import api from '../utils/api';
import { formatBytes } from '../utils/helpers';

const Dashboard = () => {
  const { t } = useTranslation();
  const [stats, setStats] = useState(null);
  const [systemInfo, setSystemInfo] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [statsRes, systemRes] = await Promise.all([
        api.get('/dashboard/stats'),
        api.get('/dashboard/system')
      ]);
      setStats(statsRes.data);
      setSystemInfo(systemRes.data);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    {
      title: t('dashboard.totalClients'),
      value: stats?.total_clients || 0,
      icon: Users,
      color: 'bg-blue-500'
    },
    {
      title: t('dashboard.activeClients'),
      value: stats?.active_clients || 0,
      icon: UserCheck,
      color: 'bg-green-500'
    },
    {
      title: t('dashboard.onlineClients'),
      value: stats?.online_clients || 0,
      icon: Wifi,
      color: 'bg-emerald-500'
    },
    {
      title: t('dashboard.disabledClients'),
      value: stats?.disabled_clients || 0,
      icon: UserX,
      color: 'bg-gray-500'
    },
    {
      title: t('dashboard.expiredClients'),
      value: stats?.expired_clients || 0,
      icon: Clock,
      color: 'bg-red-500'
    },
    {
      title: t('dashboard.totalDataUsed'),
      value: formatBytes(stats?.total_data_used || 0),
      icon: Database,
      color: 'bg-purple-500'
    }
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Page Title */}
      <div>
        <h1 className="text-2xl font-bold text-white">{t('dashboard.title')}</h1>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {statCards.map((card, index) => {
          const Icon = card.icon;
          return (
            <div
              key={index}
              className="bg-dark-card border border-dark-border rounded-xl p-6 card-hover"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-dark-muted text-sm mb-1">{card.title}</p>
                  <p className="text-2xl font-bold text-white">{card.value}</p>
                </div>
                <div className={`p-3 ${card.color} rounded-lg bg-opacity-20`}>
                  <Icon className={`w-6 h-6 ${card.color.replace('bg-', 'text-')}`} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* System Status */}
      <div className="bg-dark-card border border-dark-border rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <Server className="w-5 h-5 text-primary-500" />
          {t('dashboard.systemStatus')}
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.wireguardInstalled')}</span>
            <span className="flex items-center gap-2">
              {systemInfo?.wireguard_installed ? (
                <>
                  <CheckCircle className="w-5 h-5 text-green-500" />
                  <span className="text-green-500">{t('dashboard.yes')}</span>
                </>
              ) : (
                <>
                  <XCircle className="w-5 h-5 text-red-500" />
                  <span className="text-red-500">{t('dashboard.no')}</span>
                </>
              )}
            </span>
          </div>
          <div className="flex items-center justify-between p-4 bg-dark-bg rounded-lg">
            <span className="text-dark-text">{t('dashboard.interfaceUp')}</span>
            <span className="flex items-center gap-2">
              {systemInfo?.interface_up ? (
                <>
                  <CheckCircle className="w-5 h-5 text-green-500" />
                  <span className="text-green-500">{t('dashboard.yes')}</span>
                </>
              ) : (
                <>
                  <XCircle className="w-5 h-5 text-yellow-500" />
                  <span className="text-yellow-500">{t('dashboard.no')}</span>
                </>
              )}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
