import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Save, Bot, CreditCard, MessageSquare, Users, Gift, Plus, Edit2, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const Settings = () => {
  const [settings, setSettings] = useState({});
  const [departments, setDepartments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState('bot');
  const [showDeptModal, setShowDeptModal] = useState(false);
  const [editingDept, setEditingDept] = useState(null);
  const [deptForm, setDeptForm] = useState({ name: '', description: '', is_active: true, sort_order: 0 });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [settingsRes, deptsRes] = await Promise.all([
        axios.get(`${API_URL}/api/settings`),
        axios.get(`${API_URL}/api/departments`)
      ]);
      setSettings(settingsRes.data || {});
      setDepartments(deptsRes.data || []);
    } catch (error) {
      toast.error('خطا در دریافت تنظیمات');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await axios.put(`${API_URL}/api/settings`, settings);
      toast.success('تنظیمات ذخیره شد');
    } catch (error) {
      toast.error('خطا در ذخیره تنظیمات');
    } finally {
      setSaving(false);
    }
  };

  const handleDeptSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingDept) {
        await axios.put(`${API_URL}/api/departments/${editingDept.id}`, deptForm);
        toast.success('دپارتمان بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/departments`, deptForm);
        toast.success('دپارتمان اضافه شد');
      }
      setShowDeptModal(false);
      resetDeptForm();
      fetchData();
    } catch (error) {
      toast.error('خطا در ذخیره دپارتمان');
    }
  };

  const handleDeleteDept = async (id) => {
    if (!window.confirm('آیا از حذف این دپارتمان اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/departments/${id}`);
      toast.success('دپارتمان حذف شد');
      fetchData();
    } catch (error) {
      toast.error('خطا در حذف دپارتمان');
    }
  };

  const resetDeptForm = () => {
    setEditingDept(null);
    setDeptForm({ name: '', description: '', is_active: true, sort_order: 0 });
  };

  const openEditDeptModal = (dept) => {
    setEditingDept(dept);
    setDeptForm({
      name: dept.name,
      description: dept.description || '',
      is_active: dept.is_active,
      sort_order: dept.sort_order
    });
    setShowDeptModal(true);
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="spinner"></div>
      </div>
    );
  }

  const tabs = [
    { id: 'bot', label: 'تنظیمات ربات', icon: Bot },
    { id: 'payment', label: 'درگاه پرداخت', icon: CreditCard },
    { id: 'messages', label: 'پیام‌ها', icon: MessageSquare },
    { id: 'referral', label: 'همکاری در فروش', icon: Users },
    { id: 'departments', label: 'دپارتمان‌ها', icon: Gift }
  ];

  return (
    <div className="space-y-6" data-testid="settings-page">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">تنظیمات</h1>
          <p className="text-slate-400 text-sm mt-1">پیکربندی ربات و سیستم</p>
        </div>
        <button
          onClick={handleSave}
          disabled={saving}
          className="btn-primary flex items-center gap-2"
          data-testid="save-settings-btn"
        >
          <Save size={18} />
          {saving ? 'در حال ذخیره...' : 'ذخیره تنظیمات'}
        </button>
      </div>

      {/* Tabs */}
      <div className="tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`tab flex items-center gap-2 ${activeTab === tab.id ? 'active' : ''}`}
            data-testid={`tab-${tab.id}`}
          >
            <tab.icon size={16} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="glass-card p-6">
        {activeTab === 'bot' && (
          <div className="space-y-6">
            <h3 className="text-lg font-semibold text-white mb-4">تنظیمات ربات تلگرام</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm text-slate-400 mb-2">توکن ربات</label>
                <input
                  type="password"
                  value={settings.bot_token || ''}
                  onChange={(e) => setSettings({ ...settings, bot_token: e.target.value })}
                  className="input font-mono text-sm"
                  placeholder="1234567890:ABCdefGHIjklmnOPQrstuvWXYZ"
                  data-testid="bot-token-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام کاربری ربات</label>
                <input
                  type="text"
                  value={settings.bot_username || ''}
                  onChange={(e) => setSettings({ ...settings, bot_username: e.target.value })}
                  className="input"
                  placeholder="my_bot"
                  data-testid="bot-username-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">شناسه کانال</label>
                <input
                  type="text"
                  value={settings.channel_id || ''}
                  onChange={(e) => setSettings({ ...settings, channel_id: e.target.value })}
                  className="input"
                  placeholder="-1001234567890"
                  data-testid="channel-id-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام کانال</label>
                <input
                  type="text"
                  value={settings.channel_username || ''}
                  onChange={(e) => setSettings({ ...settings, channel_username: e.target.value })}
                  className="input"
                  placeholder="my_channel"
                  data-testid="channel-username-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">یوزرنیم پشتیبانی</label>
                <input
                  type="text"
                  value={settings.support_username || ''}
                  onChange={(e) => setSettings({ ...settings, support_username: e.target.value })}
                  className="input"
                  placeholder="support_user"
                  data-testid="support-username-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">مهلت پرداخت (دقیقه)</label>
                <input
                  type="number"
                  value={settings.payment_timeout_minutes || 30}
                  onChange={(e) => setSettings({ ...settings, payment_timeout_minutes: parseInt(e.target.value) })}
                  className="input"
                  data-testid="payment-timeout-input"
                />
              </div>
            </div>
            <div className="flex items-center gap-4 pt-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={settings.test_account_enabled || false}
                  onChange={(e) => setSettings({ ...settings, test_account_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                <span className="text-sm text-slate-300">فعال بودن اکانت تست</span>
              </label>
            </div>
          </div>
        )}

        {activeTab === 'payment' && (
          <div className="space-y-6">
            <h3 className="text-lg font-semibold text-white mb-4">تنظیمات درگاه کارت به کارت</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm text-slate-400 mb-2">شماره کارت</label>
                <input
                  type="text"
                  value={settings.card_number || ''}
                  onChange={(e) => setSettings({ ...settings, card_number: e.target.value })}
                  className="input font-mono text-lg tracking-widest"
                  placeholder="6037-XXXX-XXXX-XXXX"
                  data-testid="card-number-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام صاحب حساب</label>
                <input
                  type="text"
                  value={settings.card_holder || ''}
                  onChange={(e) => setSettings({ ...settings, card_holder: e.target.value })}
                  className="input"
                  placeholder="علی محمدی"
                  data-testid="card-holder-input"
                />
              </div>
            </div>
          </div>
        )}

        {activeTab === 'messages' && (
          <div className="space-y-6">
            <h3 className="text-lg font-semibold text-white mb-4">پیام‌های ربات</h3>
            <div>
              <label className="block text-sm text-slate-400 mb-2">پیام خوش‌آمدگویی</label>
              <textarea
                value={settings.welcome_message || ''}
                onChange={(e) => setSettings({ ...settings, welcome_message: e.target.value })}
                className="input min-h-[120px]"
                placeholder="به ربات خوش آمدید..."
                data-testid="welcome-message-input"
              />
            </div>
            <div>
              <label className="block text-sm text-slate-400 mb-2">قوانین</label>
              <textarea
                value={settings.rules_message || ''}
                onChange={(e) => setSettings({ ...settings, rules_message: e.target.value })}
                className="input min-h-[120px]"
                placeholder="قوانین استفاده از سرویس..."
                data-testid="rules-message-input"
              />
            </div>
          </div>
        )}

        {activeTab === 'referral' && (
          <div className="space-y-6">
            <h3 className="text-lg font-semibold text-white mb-4">تنظیمات همکاری در فروش</h3>
            <div className="flex items-center gap-4 mb-6">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={settings.referral_enabled || false}
                  onChange={(e) => setSettings({ ...settings, referral_enabled: e.target.checked })}
                  className="w-4 h-4"
                  data-testid="referral-enabled-checkbox"
                />
                <span className="text-sm text-slate-300">فعال بودن سیستم زیرمجموعه‌گیری</span>
              </label>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm text-slate-400 mb-2">درصد پورسانت</label>
                <input
                  type="number"
                  value={settings.referral_percent || 10}
                  onChange={(e) => setSettings({ ...settings, referral_percent: parseFloat(e.target.value) })}
                  className="input"
                  min="0"
                  max="100"
                  data-testid="referral-percent-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">حداقل برداشت (تومان)</label>
                <input
                  type="number"
                  value={settings.min_withdrawal || 50000}
                  onChange={(e) => setSettings({ ...settings, min_withdrawal: parseFloat(e.target.value) })}
                  className="input"
                  data-testid="min-withdrawal-input"
                />
              </div>
            </div>
          </div>
        )}

        {activeTab === 'departments' && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-white">دپارتمان‌های پشتیبانی</h3>
              <button
                onClick={() => { resetDeptForm(); setShowDeptModal(true); }}
                className="btn-primary text-sm flex items-center gap-2"
                data-testid="add-dept-btn"
              >
                <Plus size={16} />
                افزودن دپارتمان
              </button>
            </div>
            <div className="space-y-3">
              {departments.map((dept) => (
                <div key={dept.id} className="flex items-center justify-between p-4 bg-slate-800/50 rounded-lg border border-slate-700">
                  <div>
                    <h4 className="font-medium text-white">{dept.name}</h4>
                    {dept.description && <p className="text-sm text-slate-400">{dept.description}</p>}
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`badge ${dept.is_active ? 'badge-success' : 'badge-default'}`}>
                      {dept.is_active ? 'فعال' : 'غیرفعال'}
                    </span>
                    <button
                      onClick={() => openEditDeptModal(dept)}
                      className="p-2 text-slate-400 hover:text-blue-500"
                      data-testid={`edit-dept-${dept.id}`}
                    >
                      <Edit2 size={16} />
                    </button>
                    <button
                      onClick={() => handleDeleteDept(dept.id)}
                      className="p-2 text-slate-400 hover:text-red-500"
                      data-testid={`delete-dept-${dept.id}`}
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Department Modal */}
      {showDeptModal && (
        <div className="modal-overlay" onClick={() => setShowDeptModal(false)}>
          <div className="modal-content p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">
              {editingDept ? 'ویرایش دپارتمان' : 'افزودن دپارتمان'}
            </h2>
            <form onSubmit={handleDeptSubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام دپارتمان</label>
                <input
                  type="text"
                  value={deptForm.name}
                  onChange={(e) => setDeptForm({ ...deptForm, name: e.target.value })}
                  className="input"
                  placeholder="پشتیبانی فنی"
                  required
                  data-testid="dept-name-input"
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">توضیحات</label>
                <textarea
                  value={deptForm.description}
                  onChange={(e) => setDeptForm({ ...deptForm, description: e.target.value })}
                  className="input min-h-[60px]"
                  placeholder="توضیحات اختیاری..."
                />
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="dept_active"
                  checked={deptForm.is_active}
                  onChange={(e) => setDeptForm({ ...deptForm, is_active: e.target.checked })}
                  className="w-4 h-4"
                />
                <label htmlFor="dept_active" className="text-sm text-slate-300">فعال</label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-dept-btn">
                  {editingDept ? 'بروزرسانی' : 'افزودن'}
                </button>
                <button type="button" onClick={() => setShowDeptModal(false)} className="btn-secondary">
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

export default Settings;
