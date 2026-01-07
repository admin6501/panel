import React, { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Users as UsersIcon,
  Plus,
  Search,
  Edit,
  Trash2,
  Shield,
  ShieldCheck,
  Eye
} from 'lucide-react';
import api from '../utils/api';
import { formatDate } from '../utils/helpers';
import { useAuth } from '../contexts/AuthContext';
import Modal from '../components/Modal';
import toast from 'react-hot-toast';

const Users = () => {
  const { t, i18n } = useTranslation();
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    role: 'viewer',
    is_active: true
  });

  const isRTL = i18n.language === 'fa';

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const response = await api.get('/users');
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast.error(t('common.error'));
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        username: formData.username,
        role: formData.role,
        is_active: formData.is_active
      };

      if (formData.password) {
        data.password = formData.password;
      }

      if (selectedUser) {
        await api.put(`/users/${selectedUser.id}`, data);
        toast.success(t('users.updateSuccess'));
      } else {
        data.password = formData.password;
        await api.post('/users', data);
        toast.success(t('users.createSuccess'));
      }

      setShowModal(false);
      resetForm();
      fetchUsers();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleDelete = async (user) => {
    if (user.id === currentUser?.id) {
      toast.error(t('users.cannotDeleteSelf'));
      return;
    }

    if (!window.confirm(t('users.confirmDelete'))) return;

    try {
      await api.delete(`/users/${user.id}`);
      toast.success(t('users.deleteSuccess'));
      fetchUsers();
    } catch (error) {
      toast.error(error.response?.data?.detail || t('common.error'));
    }
  };

  const handleEdit = (user) => {
    setSelectedUser(user);
    setFormData({
      username: user.username,
      password: '',
      role: user.role,
      is_active: user.is_active
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setSelectedUser(null);
    setFormData({
      username: '',
      password: '',
      role: 'viewer',
      is_active: true
    });
  };

  const getRoleIcon = (role) => {
    switch (role) {
      case 'super_admin':
        return <ShieldCheck className="w-4 h-4 text-purple-500" />;
      case 'admin':
        return <Shield className="w-4 h-4 text-blue-500" />;
      default:
        return <Eye className="w-4 h-4 text-gray-500" />;
    }
  };

  const getRoleLabel = (role) => {
    switch (role) {
      case 'super_admin':
        return t('users.superAdmin');
      case 'admin':
        return t('users.admin');
      default:
        return t('users.viewer');
    }
  };

  const filteredUsers = users.filter(user =>
    user.username.toLowerCase().includes(searchQuery.toLowerCase())
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
          <UsersIcon className="w-7 h-7 text-primary-500" />
          {t('users.title')}
        </h1>
        <button
          onClick={() => { resetForm(); setShowModal(true); }}
          className="btn-primary flex items-center gap-2"
        >
          <Plus className="w-5 h-5" />
          {t('users.addNew')}
        </button>
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

      {/* Users Table */}
      {filteredUsers.length === 0 ? (
        <div className="text-center py-12 text-dark-muted">
          <UsersIcon className="w-16 h-16 mx-auto mb-4 opacity-50" />
          <p>{t('users.noUsers')}</p>
        </div>
      ) : (
        <div className="bg-dark-card border border-dark-border rounded-xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-dark-border">
                  <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase tracking-wider">
                    {t('users.username')}
                  </th>
                  <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase tracking-wider">
                    {t('users.role')}
                  </th>
                  <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase tracking-wider">
                    {t('users.status')}
                  </th>
                  <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase tracking-wider">
                    {t('users.createdAt')}
                  </th>
                  <th className="px-6 py-4 text-right text-xs font-medium text-dark-muted uppercase tracking-wider">
                    {t('users.actions')}
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-dark-border">
                {filteredUsers.map((user) => (
                  <tr key={user.id} className="hover:bg-dark-border/50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-dark-border rounded-lg">
                          {getRoleIcon(user.role)}
                        </div>
                        <span className="text-white font-medium">{user.username}</span>
                        {user.id === currentUser?.id && (
                          <span className="text-xs text-primary-500">(شما)</span>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-dark-text">{getRoleLabel(user.role)}</span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        user.is_active
                          ? 'bg-green-500/20 text-green-500'
                          : 'bg-red-500/20 text-red-500'
                      }`}>
                        {user.is_active ? t('users.active') : t('users.inactive')}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-dark-muted">
                      {formatDate(user.created_at)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleEdit(user)}
                          className="p-2 text-dark-muted hover:text-white hover:bg-dark-border rounded-lg transition-colors"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        {user.id !== currentUser?.id && (
                          <button
                            onClick={() => handleDelete(user)}
                            className="p-2 text-dark-muted hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Create/Edit Modal */}
      <Modal
        isOpen={showModal}
        onClose={() => { setShowModal(false); resetForm(); }}
        title={selectedUser ? t('users.edit') : t('users.addNew')}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('users.username')} *
            </label>
            <input
              type="text"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
              required
            />
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('users.password')} {!selectedUser && '*'}
            </label>
            <input
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
              required={!selectedUser}
              placeholder={selectedUser ? 'خالی بگذارید برای عدم تغییر' : ''}
            />
          </div>

          <div>
            <label className="block text-dark-text text-sm font-medium mb-2">
              {t('users.role')}
            </label>
            <select
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value })}
              className="w-full bg-dark-bg border border-dark-border rounded-lg py-2 px-4 text-white"
            >
              <option value="super_admin">{t('users.superAdmin')}</option>
              <option value="admin">{t('users.admin')}</option>
              <option value="viewer">{t('users.viewer')}</option>
            </select>
          </div>

          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="is_active"
              checked={formData.is_active}
              onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
              className="w-4 h-4 text-primary-600 bg-dark-bg border-dark-border rounded focus:ring-primary-500"
            />
            <label htmlFor="is_active" className="text-dark-text">
              {t('users.active')}
            </label>
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
    </div>
  );
};

export default Users;
