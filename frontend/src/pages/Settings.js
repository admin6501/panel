import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Settings as SettingsIcon,
  Server,
  Globe,
  Network,
  Key,
  Save,
  AlertCircle
} from 'lucide-react';
import api from '../utils/api';
import { useAuth } from '../contexts/AuthContext';
import toast from 'react-hot-toast';

const Settings = () => {
  const { t } = useTranslation();
  const { isSuperAdmin } = useAuth();
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({
    server_name: '',
    endpoint: '',
    wg_port: 51820,
    wg_dns: '1.1.1.1,8.8.8.8',
    mtu: 1420,
    persistent_keepalive: 25
  });

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      const response = await api.get('/settings');
      setSettings(response.data);
      setFormData({
        server_name: response.data.server_name || '',
        endpoint: response.data.endpoint || '',
        wg_port: response.data.wg_port || 51820,
        wg_dns: response.data.wg_dns || '1.1.1.1,8.8.8.8',
        mtu: response.data.mtu || 1420,
        persistent_keepalive: response.data.persistent_keepalive || 25
      });
    } catch (error) {
      console.error('Error fetching settings:', error);
      toast.error(t('common.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);

    try {
      await api.put('/settings', formData);
      toast.success(t('settings.saveSuccess'));
      fetchSettings();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <SettingsIcon className="w-7 h-7 text-primary-500" />
          {t('settings.title')}
        </h1>
      </div>

      {/* Endpoint Warning */}
      {!settings?.endpoint && (
        <div className="bg-yellow-500/10 border border-yellow-500/50 rounded-xl p-4 flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-yellow-500 flex-shrink-0 mt-0.5" />
          <p className="text-yellow-500">{t('settings.endpointRequired')}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Server Settings */}
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <Server className="w-5 h-5 text-primary-500" />
            {t('settings.title')}
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('settings.serverName')}
              </label>
              <input
                type="text"
                value={formData.server_name}
                onChange={(e) => setFormData({ ...formData, server_name: e.target.value })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                disabled={!isSuperAdmin()}
              />
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                <Globe className="w-4 h-4 inline ml-1" />
                {t('settings.endpoint')} *
              </label>
              <input
                type="text"
                value={formData.endpoint}
                onChange={(e) => setFormData({ ...formData, endpoint: e.target.value })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                placeholder="example.com or 1.2.3.4"
                disabled={!isSuperAdmin()}
              />
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                <Network className="w-4 h-4 inline ml-1" />
                {t('settings.port')}
              </label>
              <input
                type="number"
                value={formData.wg_port}
                onChange={(e) => setFormData({ ...formData, wg_port: parseInt(e.target.value) })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                disabled={!isSuperAdmin()}
              />
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('settings.dns')}
              </label>
              <input
                type="text"
                value={formData.wg_dns}
                onChange={(e) => setFormData({ ...formData, wg_dns: e.target.value })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                placeholder="1.1.1.1,8.8.8.8"
                disabled={!isSuperAdmin()}
              />
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('settings.mtu')}
              </label>
              <input
                type="number"
                value={formData.mtu}
                onChange={(e) => setFormData({ ...formData, mtu: parseInt(e.target.value) })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                disabled={!isSuperAdmin()}
              />
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('settings.keepalive')}
              </label>
              <input
                type="number"
                value={formData.persistent_keepalive}
                onChange={(e) => setFormData({ ...formData, persistent_keepalive: parseInt(e.target.value) })}
                className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                disabled={!isSuperAdmin()}
              />
            </div>
          </div>
        </div>

        {/* Public Key (Read Only) */}
        <div className="bg-dark-card border border-dark-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <Key className="w-5 h-5 text-primary-500" />
            {t('settings.publicKey')}
          </h2>
          <div className="bg-dark-bg border border-dark-border rounded-lg p-4">
            <code className="text-green-400 break-all text-sm">
              {settings?.server_public_key || 'N/A'}
            </code>
          </div>
        </div>

        {/* Save Button */}
        {isSuperAdmin() && (
          <button
            type="submit"
            disabled={saving}
            className="btn-primary flex items-center gap-2"
          >
            {saving ? (
              <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <Save className="w-5 h-5" />
            )}
            {t('settings.save')}
          </button>
        )}
      </form>
    </div>
  );
};

export default Settings;
