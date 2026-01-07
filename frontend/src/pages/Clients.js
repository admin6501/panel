import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Plus,
  Search,
  Download,
  QrCode,
  Edit,
  Trash2,
  Power,
  RotateCcw,
  Shield,
  Wifi,
  WifiOff,
  MoreVertical,
  Clock,
  Infinity,
  Database
} from 'lucide-react';
import api from '../utils/api';
import { formatBytes, formatDate, formatDateForInput, getStatusColor } from '../utils/helpers';
import { useAuth } from '../contexts/AuthContext';
import Modal from '../components/Modal';
import toast from 'react-hot-toast';

const Clients = () => {
  const { t, i18n } = useTranslation();
  const { isAdmin } = useAuth();
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [showQRModal, setShowQRModal] = useState(false);
  const [selectedClient, setSelectedClient] = useState(null);
  const [qrImage, setQrImage] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    data_limit: '',
    data_limit_unit: 'GB',
    expiry_date: '',
    note: ''
  });
  const [openMenu, setOpenMenu] = useState(null);

  const isRTL = i18n.language === 'fa';

  useEffect(() => {
    fetchClients();
  }, []);

  const fetchClients = async () => {
    try {
      const response = await api.get('/clients');
      setClients(response.data);
    } catch (error) {
      console.error('Error fetching clients:', error);
      toast.error(t('common.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        name: formData.name,
        email: formData.email || null,
        data_limit: formData.data_limit
          ? parseFloat(formData.data_limit) * getUnitMultiplier(formData.data_limit_unit)
          : null,
        expiry_date: formData.expiry_date || null,
        note: formData.note || null
      };

      if (selectedClient) {
        await api.put(`/clients/${selectedClient.id}`, data);
        toast.success(t('clients.updateSuccess'));
      } else {
        await api.post('/clients', data);
        toast.success(t('clients.createSuccess'));
      }

      setShowModal(false);
      resetForm();
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleDelete = async (client) => {
    if (!window.confirm(t('clients.confirmDelete'))) return;

    try {
      await api.delete(`/clients/${client.id}`);
      toast.success(t('clients.deleteSuccess'));
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleToggleStatus = async (client) => {
    try {
      await api.put(`/clients/${client.id}`, { is_enabled: !client.is_enabled });
      toast.success(t('clients.updateSuccess'));
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleResetData = async (client) => {
    try {
      await api.post(`/clients/${client.id}/reset-data`);
      toast.success(t('common.success'));
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleResetExpiry = async (client, days = 30) => {
    try {
      await api.post(`/clients/${client.id}/reset-expiry?days=${days}`);
      toast.success(t('clients.expiryExtended'));
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleRemoveExpiry = async (client) => {
    try {
      await api.post(`/clients/${client.id}/remove-expiry`);
      toast.success(t('common.success'));
      fetchClients();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleDownloadConfig = async (client) => {
    try {
      const response = await api.get(`/clients/${client.id}/config`, {
        responseType: 'blob'
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `${client.name}.conf`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleShowQR = async (client) => {
    try {
      const response = await api.get(`/clients/${client.id}/qrcode`, {
        responseType: 'blob'
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      setQrImage(url);
      setSelectedClient(client);
      setShowQRModal(true);
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleEdit = (client) => {
    setSelectedClient(client);
    setFormData({
      name: client.name,
      email: client.email || '',
      data_limit: client.data_limit ? (client.data_limit / (1024 * 1024 * 1024)).toFixed(2) : '',
      data_limit_unit: 'GB',
      expiry_date: formatDateForInput(client.expiry_date),
      note: client.note || ''
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setSelectedClient(null);
    setFormData({
      name: '',
      email: '',
      data_limit: '',
      data_limit_unit: 'GB',
      expiry_date: '',
      note: ''
    });
  };

  const getUnitMultiplier = (unit) => {
    const units = { 'KB': 1024, 'MB': 1024 * 1024, 'GB': 1024 * 1024 * 1024, 'TB': 1024 * 1024 * 1024 * 1024 };
    return units[unit] || 1;
  };

  const getStatusLabel = (status) => {
    const labels = {
      active: t('clients.active'),
      disabled: t('clients.disabled'),
      expired: t('clients.expired'),
      data_limit_reached: t('clients.dataLimitReached')
    };
    return labels[status] || status;
  };

  const filteredClients = clients.filter(client =>
    client.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    client.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    client.address?.includes(searchQuery)
  );

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
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Shield className="w-7 h-7 text-primary-500" />
          {t('clients.title')}
        </h1>
        {isAdmin() && (
          <button
            onClick={() => { resetForm(); setShowModal(true); }}
            className="btn-primary flex items-center gap-2"
          >
            <Plus className="w-5 h-5" />
            {t('clients.addNew')}
          </button>
        )}
      </div>

      {/* Search */}
      <div className="relative">
        <Search className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder={t('common.search')}
          className={`w-full bg-dark-card border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500`}
        />
      </div>

      {/* Clients Grid */}
      {filteredClients.length === 0 ? (
        <div className="text-center py-12 text-dark-muted">
          <Shield className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{t('clients.noClients')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filteredClients.map((client) => (
            <div
              key={client.id}
              className="bg-dark-card border border-dark-border rounded-xl p-4 card-hover relative"
            >
              {/* Header */}
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-lg ${client.is_online ? 'bg-green-500/20' : 'bg-dark-border'}`}>
                    {client.is_online ? (
                      <Wifi className="w-5 h-5 text-green-500" />
                    ) : (
                      <WifiOff className="w-5 h-5 text-dark-muted" />
                    )}
                  </div>
                  <div>
                    <h3 className="font-semibold text-white">{client.name}</h3>
                    <p className="text-dark-muted text-sm">{client.address}</p>
                  </div>
                </div>
                
                {/* Actions Menu */}
                <div className="relative">
                  <button
                    onClick={() => setOpenMenu(openMenu === client.id ? null : client.id)}
                    className="p-1 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"
                  >
                    <MoreVertical className="w-5 h-5" />
                  </button>
                  
                  {openMenu === client.id && (
                    <div className={`absolute ${isRTL ? 'left-0' : 'right-0'} mt-2 w-48 bg-dark-card border border-dark-border rounded-lg shadow-xl z-10`}>
                      <button
                        onClick={() => { handleDownloadConfig(client); setOpenMenu(null); }}
                        className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"
                      >
                        <Download className="w-4 h-4" />
                        {t('clients.downloadConfig')}
                      </button>
                      <button
                        onClick={() => { handleShowQR(client); setOpenMenu(null); }}
                        className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"
                      >
                        <QrCode className="w-4 h-4" />
                        {t('clients.showQR')}
                      </button>
                      {isAdmin() && (
                        <>
                          <button
                            onClick={() => { handleEdit(client); setOpenMenu(null); }}
                            className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                            {t('clients.edit')}
                          </button>
                          <button
                            onClick={() => { handleToggleStatus(client); setOpenMenu(null); }}
                            className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"
                          >
                            <Power className="w-4 h-4" />
                            {client.is_enabled ? t('clients.disable') : t('clients.enable')}
                          </button>
                          <button
                            onClick={() => { handleResetData(client); setOpenMenu(null); }}
                            className="w-full flex items-center gap-2 px-4 py-2 text-dark-text hover:bg-dark-border transition-colors"
                          >
                            <RotateCcw className="w-4 h-4" />
                            {t('clients.resetData')}
                          </button>
                          <button
                            onClick={() => { handleDelete(client); setOpenMenu(null); }}
                            className="w-full flex items-center gap-2 px-4 py-2 text-red-400 hover:bg-red-500/10 transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                            {t('clients.delete')}
                          </button>
                        </>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Status Badge */}
              <div className="flex items-center gap-2 mb-4">
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(client.status)} bg-opacity-20 ${getStatusColor(client.status).replace('bg-', 'text-')}`}>
                  {getStatusLabel(client.status)}
                </span>
                {client.is_online && (
                  <span className="px-2 py-1 rounded-full text-xs font-medium bg-green-500/20 text-green-500">
                    {t('clients.online')}
                  </span>
                )}
              </div>

              {/* Info */}
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.dataUsed')}:</span>
                  <span className="text-white">{formatBytes(client.data_used)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.dataLimit')}:</span>
                  <span className="text-white">
                    {client.data_limit ? formatBytes(client.data_limit) : t('clients.unlimited')}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-dark-muted">{t('clients.expiryDate')}:</span>
                  <span className="text-white">
                    {client.expiry_date ? formatDate(client.expiry_date) : t('clients.never')}
                  </span>
                </div>
              </div>

              {/* Data Usage Bar */}
              {client.data_limit && (
                <div className="mt-4">
                  <div className="w-full bg-dark-border rounded-full h-2">
                    <div
                      className={`h-2 rounded-full transition-all ${
                        (client.data_used / client.data_limit) > 0.9
                          ? 'bg-red-500'
                          : (client.data_used / client.data_limit) > 0.7
                          ? 'bg-yellow-500'
                          : 'bg-green-500'
                      }`}
                      style={{ width: `${Math.min((client.data_used / client.data_limit) * 100, 100)}%` }}
                    />
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Create/Edit Modal */}
      <Modal
        isOpen={showModal}
        onClose={() => { setShowModal(false); resetForm(); }}
        title={selectedClient ? t('clients.edit') : t('clients.addNew')}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('clients.name')} *
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
              required
            />
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('clients.email')}
            </label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
            />
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('clients.dataLimit')}
            </label>
            <div className="flex gap-2">
              <input
                type="number"
                value={formData.data_limit}
                onChange={(e) => setFormData({ ...formData, data_limit: e.target.value })}
                className="flex-1 bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
                placeholder={t('clients.unlimited')}
                min="0"
                step="0.01"
              />
              <select
                value={formData.data_limit_unit}
                onChange={(e) => setFormData({ ...formData, data_limit_unit: e.target.value })}
                className="bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
              >
                <option value="MB">MB</option>
                <option value="GB">GB</option>
                <option value="TB">TB</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('clients.expiryDate')}
            </label>
            <input
              type="date"
              value={formData.expiry_date}
              onChange={(e) => setFormData({ ...formData, expiry_date: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
            />
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('clients.note')}
            </label>
            <textarea
              value={formData.note}
              onChange={(e) => setFormData({ ...formData, note: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
              rows="3"
            />
          </div>

          <div className="flex gap-3 pt-4">
            <button type="submit" className="btn-primary flex-1">
              {t('common.save')}
            </button>
            <button
              type="button"
              onClick={() => { setShowModal(false); resetForm(); }}
              className="btn-secondary flex-1"
            >
              {t('common.cancel')}
            </button>
          </div>
        </form>
      </Modal>

      {/* QR Code Modal */}
      <Modal
        isOpen={showQRModal}
        onClose={() => { setShowQRModal(false); setQrImage(null); }}
        title={t('clients.qrTitle')}
        size="sm"
      >
        <div className="text-center">
          {qrImage && (
            <img src={qrImage} alt="QR Code" className="mx-auto mb-4 rounded-lg" />
          )}
          <p className="text-dark-muted">{t('clients.scanQR')}</p>
          <p className="text-white font-medium mt-2">{selectedClient?.name}</p>
        </div>
      </Modal>

      {/* Click outside to close menu */}
      {openMenu && (
        <div
          className="fixed inset-0 z-0"
          onClick={() => setOpenMenu(null)}
        />
      )}
    </div>
  );
};

export default Clients;
