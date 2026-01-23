import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, Package, RefreshCw } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const Plans = () => {
  const [plans, setPlans] = useState([]);
  const [servers, setServers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    price: '',
    duration_days: '',
    traffic_gb: '',
    user_limit: '1',
    server_ids: [],
    is_active: true,
    is_test: false,
    sort_order: '0'
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [plansRes, serversRes] = await Promise.all([
        axios.get(`${API_URL}/api/plans`),
        axios.get(`${API_URL}/api/servers`)
      ]);
      setPlans(plansRes.data);
      setServers(serversRes.data);
    } catch (error) {
      toast.error('خطا در دریافت اطلاعات');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...formData,
        price: parseFloat(formData.price),
        duration_days: parseInt(formData.duration_days),
        traffic_gb: formData.traffic_gb ? parseFloat(formData.traffic_gb) : null,
        user_limit: parseInt(formData.user_limit),
        sort_order: parseInt(formData.sort_order)
      };

      if (editingPlan) {
        await axios.put(`${API_URL}/api/plans/${editingPlan.id}`, data);
        toast.success('پلن بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/plans`, data);
        toast.success('پلن اضافه شد');
      }
      setShowModal(false);
      resetForm();
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره پلن');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('آیا از حذف این پلن اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/plans/${id}`);
      toast.success('پلن حذف شد');
      fetchData();
    } catch (error) {
      toast.error('خطا در حذف پلن');
    }
  };

  const openEditModal = (plan) => {
    setEditingPlan(plan);
    setFormData({
      name: plan.name,
      description: plan.description || '',
      price: plan.price.toString(),
      duration_days: plan.duration_days.toString(),
      traffic_gb: plan.traffic_gb?.toString() || '',
      user_limit: plan.user_limit.toString(),
      server_ids: plan.server_ids || [],
      is_active: plan.is_active,
      is_test: plan.is_test,
      sort_order: plan.sort_order.toString()
    });
    setShowModal(true);
  };

  const resetForm = () => {
    setEditingPlan(null);
    setFormData({
      name: '',
      description: '',
      price: '',
      duration_days: '',
      traffic_gb: '',
      user_limit: '1',
      server_ids: [],
      is_active: true,
      is_test: false,
      sort_order: '0'
    });
  };

  const toggleServer = (serverId) => {
    setFormData(prev => ({
      ...prev,
      server_ids: prev.server_ids.includes(serverId)
        ? prev.server_ids.filter(id => id !== serverId)
        : [...prev.server_ids, serverId]
    }));
  };

  return (
    <div className="space-y-6" data-testid="plans-page">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white">پلن‌ها</h1>
          <p className="text-slate-400 text-sm mt-1">{plans.length} پلن</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchData} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
          <button
            onClick={() => { resetForm(); setShowModal(true); }}
            className="btn-primary flex items-center gap-2"
            data-testid="add-plan-btn"
          >
            <Plus size={18} />
            افزودن پلن
          </button>
        </div>
      </div>

      {/* Plans Grid */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="spinner"></div>
        </div>
      ) : plans.length === 0 ? (
        <div className="text-center py-12 text-slate-400">
          هنوز پلنی اضافه نشده است
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {plans.map((plan) => (
            <div key={plan.id} className="glass-card p-5" data-testid={`plan-card-${plan.id}`}>
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-3 rounded-lg ${plan.is_test ? 'bg-purple-500/10' : 'bg-blue-500/10'}`}>
                    <Package size={22} className={plan.is_test ? 'text-purple-500' : 'text-blue-500'} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-white">{plan.name}</h3>
                    <p className="text-xs text-slate-500">{plan.duration_days} روز</p>
                  </div>
                </div>
                <div className="flex gap-1">
                  {plan.is_test && <span className="badge badge-info">تست</span>}
                  <span className={`badge ${plan.is_active ? 'badge-success' : 'badge-default'}`}>
                    {plan.is_active ? 'فعال' : 'غیرفعال'}
                  </span>
                </div>
              </div>

              {plan.description && (
                <p className="text-sm text-slate-400 mb-4">{plan.description}</p>
              )}

              <div className="space-y-2 text-sm mb-4">
                <div className="flex justify-between text-slate-400">
                  <span>حجم:</span>
                  <span className="text-white">{plan.traffic_gb ? `${plan.traffic_gb} GB` : 'نامحدود'}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>تعداد کاربر:</span>
                  <span className="text-white">{plan.user_limit}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>فروش:</span>
                  <span className="text-white">{plan.sales_count || 0}</span>
                </div>
              </div>

              <div className="text-xl font-bold text-blue-400 mb-4 font-mono">
                {formatPrice(plan.price)}
              </div>

              <div className="flex items-center gap-2 pt-4 border-t border-[#1e293b]">
                <button
                  onClick={() => openEditModal(plan)}
                  className="flex-1 btn-secondary text-sm flex items-center justify-center gap-1"
                  data-testid={`edit-plan-${plan.id}`}
                >
                  <Edit2 size={16} />
                  ویرایش
                </button>
                <button
                  onClick={() => handleDelete(plan.id)}
                  className="p-2 text-slate-400 hover:text-red-500"
                  data-testid={`delete-plan-${plan.id}`}
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
          <div className="modal-content p-6 max-w-lg" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-white mb-6">
              {editingPlan ? 'ویرایش پلن' : 'افزودن پلن'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">نام پلن</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="input"
                  placeholder="پلن یک ماهه"
                  required
                  data-testid="plan-name-input"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">قیمت (تومان)</label>
                  <input
                    type="number"
                    value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                    className="input"
                    placeholder="50000"
                    required
                    data-testid="plan-price-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">مدت (روز)</label>
                  <input
                    type="number"
                    value={formData.duration_days}
                    onChange={(e) => setFormData({ ...formData, duration_days: e.target.value })}
                    className="input"
                    placeholder="30"
                    required
                    data-testid="plan-duration-input"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">حجم (GB)</label>
                  <input
                    type="number"
                    value={formData.traffic_gb}
                    onChange={(e) => setFormData({ ...formData, traffic_gb: e.target.value })}
                    className="input"
                    placeholder="خالی = نامحدود"
                    data-testid="plan-traffic-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">تعداد کاربر</label>
                  <input
                    type="number"
                    value={formData.user_limit}
                    onChange={(e) => setFormData({ ...formData, user_limit: e.target.value })}
                    className="input"
                    placeholder="1"
                    required
                    data-testid="plan-userlimit-input"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">توضیحات</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="input min-h-[60px]"
                  placeholder="توضیحات اختیاری..."
                />
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-2">سرورها</label>
                <div className="flex flex-wrap gap-2">
                  {servers.map((server) => (
                    <button
                      key={server.id}
                      type="button"
                      onClick={() => toggleServer(server.id)}
                      className={`px-3 py-1.5 rounded-lg text-sm transition-colors ${
                        formData.server_ids.includes(server.id)
                          ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                          : 'bg-slate-800 text-slate-400 border border-slate-700'
                      }`}
                    >
                      {server.name}
                    </button>
                  ))}
                  {servers.length === 0 && (
                    <span className="text-slate-500 text-sm">سروری موجود نیست</span>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-4">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                    className="w-4 h-4"
                  />
                  <span className="text-sm text-slate-300">فعال</span>
                </label>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={formData.is_test}
                    onChange={(e) => setFormData({ ...formData, is_test: e.target.checked })}
                    className="w-4 h-4"
                  />
                  <span className="text-sm text-slate-300">پلن تست</span>
                </label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-plan-btn">
                  {editingPlan ? 'بروزرسانی' : 'افزودن'}
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

export default Plans;
