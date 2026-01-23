import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, Server as ServerIcon, RefreshCw, CheckCircle, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const Servers = () => {
  const [servers, setServers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingServer, setEditingServer] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    panel_url: '',
    panel_username: '',
    panel_password: '',
    is_active: true,
    max_users: '',
    description: ''
  });

  useEffect(() => {
    fetchServers();
  }, []);

  const fetchServers = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/servers`);
      setServers(response.data);
    } catch (error) {
      toast.error('خطا در دریافت سرورها');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...formData,
        max_users: formData.max_users ? parseInt(formData.max_users) : null
      };

      if (editingServer) {
        await axios.put(`${API_URL}/api/servers/${editingServer.id}`, data);
        toast.success('سرور بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/servers`, data);
        toast.success('سرور اضافه شد');
      }
      setShowModal(false);
      resetForm();
      fetchServers();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره سرور');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('آیا از حذف این سرور اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/servers/${id}`);
      toast.success('سرور حذف شد');
      fetchServers();
    } catch (error) {
      toast.error('خطا در حذف سرور');
    }
  };

  const handleTest = async (id) => {
    try {
      const response = await axios.post(`${API_URL}/api/servers/${id}/test`);
      if (response.data.status === 'success') {
        toast.success(response.data.message);
      } else {
        toast.error(response.data.message);
      }
    } catch (error) {
      toast.error('خطا در تست اتصال');
    }
  };

  const openEditModal = (server) => {
    setEditingServer(server);
    setFormData({
      name: server.name,
      panel_url: server.panel_url,
      panel_username: server.panel_username,
      panel_password: server.panel_password,
      is_active: server.is_active,
      max_users: server.max_users || '',
      description: server.description || ''
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setEditingServer(null);
    setFormData({
      name: '',
      panel_url: '',
      panel_username: '',
      panel_password: '',
      is_active: true,
      max_users: '',
      description: ''
    });
  };

  return (
    <div className="space-y-6" data-testid="servers-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">سرورها (پنل سنایی)</h1>
          <p className="text-slate-400 text-sm mt-1">{servers.length} سرور</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchServers} className="btn-secondary flex items-center gap-2">
            <RefreshCw size={18} />
          </button>
          <button
            onClick={() => { resetForm(); setShowModal(true); }}
            className="btn-primary flex items-center gap-2"
            data-testid="add-server-btn"
          >
            <Plus size={18} />
            افزودن سرور
          </button>
        </div>
      </div>

      {/* Server Cards */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="spinner"></div>
        </div>
      ) : servers.length === 0 ? (
        <div className="text-center py-12 text-slate-400">
          هنوز سروری اضافه نشده است
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {servers.map((server) => (
            <div key={server.id} className="glass-card p-5" data-testid={`server-card-${server.id}`}>
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-3 rounded-lg ${server.is_active ? 'bg-green-500/10' : 'bg-slate-500/10'}`}>
                    <ServerIcon size={22} className={server.is_active ? 'text-green-500' : 'text-slate-500'} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-white">{server.name}</h3>
                    <p className="text-xs text-slate-500 font-mono">{server.panel_url}</p>
                  </div>
                </div>
                <span className={`badge ${server.is_active ? 'badge-success' : 'badge-default'}`}>
                  {server.is_active ? 'فعال' : 'غیرفعال'}
                </span>
              </div>

              {server.description && (
                <p className="text-sm text-slate-400 mb-4">{server.description}</p>
              )}

              <div className="flex items-center justify-between text-sm text-slate-400 mb-4">
                <span>کاربران: {server.current_users || 0}{server.max_users ? ` / ${server.max_users}` : ''}</span>
              </div>

              <div className="flex items-center gap-2 pt-4 border-t border-[#1e293b]">
                <button
                  onClick={() => handleTest(server.id)}
                  className="flex-1 btn-secondary text-sm flex items-center justify-center gap-1"
                  data-testid={`test-server-${server.id}`}
                >
                  <CheckCircle size={16} />
                  تست اتصال
                </button>
                <button
                  onClick={() => openEditModal(server)}
                  className="p-2 text-slate-400 hover:text-blue-500"
                  data-testid={`edit-server-${server.id}`}
                >
                  <Edit2 size={18} />
                </button>
                <button
                  onClick={() => handleDelete(server.id)}
                  className="p-2 text-slate-400 hover:text-red-500"
                  data-testid={`delete-server-${server.id}`}
                >
                  <Trash2 size={18} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-content p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">
              {editingServer ? 'ویرایش سرور' : 'افزودن سرور'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام سرور</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="input"
                  placeholder="سرور آلمان ۱"
                  required
                  data-testid="server-name-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">آدرس پنل</label>
                <input
                  type="url"
                  value={formData.panel_url}
                  onChange={(e) => setFormData({ ...formData, panel_url: e.target.value })}
                  className="input font-mono text-sm"
                  placeholder="https://panel.example.com"
                  required
                  data-testid="server-url-input"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">نام کاربری پنل</label>
                  <input
                    type="text"
                    value={formData.panel_username}
                    onChange={(e) => setFormData({ ...formData, panel_username: e.target.value })}
                    className="input"
                    required
                    data-testid="server-username-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">رمز عبور پنل</label>
                  <input
                    type="password"
                    value={formData.panel_password}
                    onChange={(e) => setFormData({ ...formData, panel_password: e.target.value })}
                    className="input"
                    required
                    data-testid="server-password-input"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">حداکثر کاربر (اختیاری)</label>
                <input
                  type="number"
                  value={formData.max_users}
                  onChange={(e) => setFormData({ ...formData, max_users: e.target.value })}
                  className="input"
                  placeholder="100"
                  data-testid="server-maxusers-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">توضیحات</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="input min-h-[80px]"
                  placeholder="توضیحات اختیاری..."
                  data-testid="server-description-input"
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="is_active"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="w-4 h-4"
                  data-testid="server-active-checkbox"
                />
                <label htmlFor="is_active" className="text-sm text-slate-300">فعال</label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-server-btn">
                  {editingServer ? 'بروزرسانی' : 'افزودن'}
                </button>
                <button type="button" onClick={() => setShowModal(false)} className="btn-secondary">
                  انصراف
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Servers;
