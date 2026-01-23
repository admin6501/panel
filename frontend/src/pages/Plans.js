import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, Package, RefreshCw, FolderPlus, Folder, Infinity } from 'lucide-react';
import toast from 'react-hot-toast';

const API_URL = process.env.REACT_APP_BACKEND_URL;

const formatPrice = (price) => {
  return new Intl.NumberFormat('fa-IR').format(price) + ' تومان';
};

const Plans = () => {
  const [plans, setPlans] = useState([]);
  const [categories, setCategories] = useState([]);
  const [servers, setServers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showPlanModal, setShowPlanModal] = useState(false);
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null);
  const [editingCategory, setEditingCategory] = useState(null);
  const [selectedCategory, setSelectedCategory] = useState('');
  const [planForm, setPlanForm] = useState({
    name: '',
    description: '',
    category_id: '',
    price: '',
    duration_days: '',
    duration_unlimited: false,
    traffic_gb: '',
    traffic_unlimited: false,
    user_limit: '1',
    server_ids: [],
    is_active: true,
    is_test: false,
    sort_order: '0'
  });
  const [categoryForm, setCategoryForm] = useState({
    name: '',
    description: '',
    icon: '',
    color: '#3b82f6',
    is_active: true,
    sort_order: '0'
  });

  useEffect(() => {
    fetchData();
  }, [selectedCategory]);

  const fetchData = async () => {
    try {
      const params = selectedCategory ? `?category_id=${selectedCategory}` : '';
      const [plansRes, categoriesRes, serversRes] = await Promise.all([
        axios.get(`${API_URL}/api/plans${params}`),
        axios.get(`${API_URL}/api/categories`),
        axios.get(`${API_URL}/api/servers`)
      ]);
      setPlans(plansRes.data);
      setCategories(categoriesRes.data);
      setServers(serversRes.data);
    } catch (error) {
      toast.error('خطا در دریافت اطلاعات');
    } finally {
      setLoading(false);
    }
  };

  // Plan handlers
  const handlePlanSubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        name: planForm.name,
        description: planForm.description || null,
        category_id: planForm.category_id || null,
        price: parseFloat(planForm.price),
        duration_days: planForm.duration_unlimited ? null : (planForm.duration_days ? parseInt(planForm.duration_days) : null),
        traffic_gb: planForm.traffic_unlimited ? null : (planForm.traffic_gb ? parseFloat(planForm.traffic_gb) : null),
        user_limit: parseInt(planForm.user_limit),
        server_ids: planForm.server_ids,
        is_active: planForm.is_active,
        is_test: planForm.is_test,
        sort_order: parseInt(planForm.sort_order)
      };

      if (editingPlan) {
        await axios.put(`${API_URL}/api/plans/${editingPlan.id}`, data);
        toast.success('پلن بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/plans`, data);
        toast.success('پلن اضافه شد');
      }
      setShowPlanModal(false);
      resetPlanForm();
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره پلن');
    }
  };

  const handleDeletePlan = async (id) => {
    if (!window.confirm('آیا از حذف این پلن اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/plans/${id}`);
      toast.success('پلن حذف شد');
      fetchData();
    } catch (error) {
      toast.error('خطا در حذف پلن');
    }
  };

  const openEditPlanModal = (plan) => {
    setEditingPlan(plan);
    setPlanForm({
      name: plan.name,
      description: plan.description || '',
      category_id: plan.category_id || '',
      price: plan.price.toString(),
      duration_days: plan.duration_days?.toString() || '',
      duration_unlimited: plan.duration_days === null,
      traffic_gb: plan.traffic_gb?.toString() || '',
      traffic_unlimited: plan.traffic_gb === null,
      user_limit: plan.user_limit.toString(),
      server_ids: plan.server_ids || [],
      is_active: plan.is_active,
      is_test: plan.is_test,
      sort_order: plan.sort_order.toString()
    });
    setShowPlanModal(true);
  };

  const resetPlanForm = () => {
    setEditingPlan(null);
    setPlanForm({
      name: '',
      description: '',
      category_id: selectedCategory || '',
      price: '',
      duration_days: '',
      duration_unlimited: false,
      traffic_gb: '',
      traffic_unlimited: false,
      user_limit: '1',
      server_ids: [],
      is_active: true,
      is_test: false,
      sort_order: '0'
    });
  };

  // Category handlers
  const handleCategorySubmit = async (e) => {
    e.preventDefault();
    try {
      const data = {
        ...categoryForm,
        sort_order: parseInt(categoryForm.sort_order)
      };

      if (editingCategory) {
        await axios.put(`${API_URL}/api/categories/${editingCategory.id}`, data);
        toast.success('دسته‌بندی بروزرسانی شد');
      } else {
        await axios.post(`${API_URL}/api/categories`, data);
        toast.success('دسته‌بندی اضافه شد');
      }
      setShowCategoryModal(false);
      resetCategoryForm();
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در ذخیره دسته‌بندی');
    }
  };

  const handleDeleteCategory = async (id) => {
    if (!window.confirm('آیا از حذف این دسته‌بندی اطمینان دارید؟')) return;
    try {
      await axios.delete(`${API_URL}/api/categories/${id}`);
      toast.success('دسته‌بندی حذف شد');
      if (selectedCategory === id) setSelectedCategory('');
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.detail || 'خطا در حذف دسته‌بندی');
    }
  };

  const openEditCategoryModal = (category) => {
    setEditingCategory(category);
    setCategoryForm({
      name: category.name,
      description: category.description || '',
      icon: category.icon || '',
      color: category.color || '#3b82f6',
      is_active: category.is_active,
      sort_order: category.sort_order.toString()
    });
    setShowCategoryModal(true);
  };

  const resetCategoryForm = () => {
    setEditingCategory(null);
    setCategoryForm({
      name: '',
      description: '',
      icon: '',
      color: '#3b82f6',
      is_active: true,
      sort_order: '0'
    });
  };

  const toggleServer = (serverId) => {
    setPlanForm(prev => ({
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
          <h1 className="text-2xl font-bold text-foreground">پلن‌ها و دسته‌بندی‌ها</h1>
          <p className="text-muted-foreground text-sm mt-1">{plans.length} پلن در {categories.length} دسته‌بندی</p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchData} className="btn-secondary">
            <RefreshCw size={18} />
          </button>
          <button
            onClick={() => { resetCategoryForm(); setShowCategoryModal(true); }}
            className="btn-secondary flex items-center gap-2"
            data-testid="add-category-btn"
          >
            <FolderPlus size={18} />
            دسته‌بندی
          </button>
          <button
            onClick={() => { resetPlanForm(); setShowPlanModal(true); }}
            className="btn-primary flex items-center gap-2"
            data-testid="add-plan-btn"
          >
            <Plus size={18} />
            افزودن پلن
          </button>
        </div>
      </div>

      {/* Categories */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setSelectedCategory('')}
          className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
            selectedCategory === '' 
              ? 'bg-primary text-primary-foreground' 
              : 'bg-card text-muted-foreground hover:text-foreground border border-border'
          }`}
          data-testid="category-all"
        >
          همه پلن‌ها
        </button>
        {categories.map((cat) => (
          <div key={cat.id} className="flex items-center gap-1">
            <button
              onClick={() => setSelectedCategory(cat.id)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center gap-2 ${
                selectedCategory === cat.id 
                  ? 'bg-primary text-primary-foreground' 
                  : 'bg-card text-muted-foreground hover:text-foreground border border-border'
              }`}
              style={selectedCategory === cat.id ? {} : { borderColor: cat.color + '40' }}
              data-testid={`category-${cat.id}`}
            >
              <Folder size={16} style={{ color: cat.color }} />
              {cat.name}
            </button>
            <button
              onClick={() => openEditCategoryModal(cat)}
              className="p-1 text-muted-foreground hover:text-primary"
            >
              <Edit2 size={14} />
            </button>
            <button
              onClick={() => handleDeleteCategory(cat.id)}
              className="p-1 text-muted-foreground hover:text-destructive"
            >
              <Trash2 size={14} />
            </button>
          </div>
        ))}
      </div>

      {/* Plans Grid */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="spinner"></div>
        </div>
      ) : plans.length === 0 ? (
        <div className="text-center py-12 text-muted-foreground">
          {selectedCategory ? 'در این دسته‌بندی پلنی وجود ندارد' : 'هنوز پلنی اضافه نشده است'}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {plans.map((plan) => (
            <div key={plan.id} className="glass-card p-5" data-testid={`plan-card-${plan.id}`}>
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-3 rounded-lg ${plan.is_test ? 'bg-purple-500/10' : 'bg-primary/10'}`}>
                    <Package size={22} className={plan.is_test ? 'text-purple-500' : 'text-primary'} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-foreground">{plan.name}</h3>
                    {plan.category && (
                      <p className="text-xs flex items-center gap-1" style={{ color: plan.category.color }}>
                        <Folder size={12} />
                        {plan.category.name}
                      </p>
                    )}
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
                <p className="text-sm text-muted-foreground mb-4">{plan.description}</p>
              )}

              <div className="space-y-2 text-sm mb-4">
                <div className="flex justify-between text-muted-foreground">
                  <span>مدت:</span>
                  <span className="text-foreground flex items-center gap-1">
                    {plan.duration_days === null ? (
                      <><Infinity size={16} className="text-primary" /> نامحدود</>
                    ) : (
                      `${plan.duration_days} روز`
                    )}
                  </span>
                </div>
                <div className="flex justify-between text-muted-foreground">
                  <span>حجم:</span>
                  <span className="text-foreground flex items-center gap-1">
                    {plan.traffic_gb === null ? (
                      <><Infinity size={16} className="text-primary" /> نامحدود</>
                    ) : (
                      `${plan.traffic_gb} GB`
                    )}
                  </span>
                </div>
                <div className="flex justify-between text-muted-foreground">
                  <span>تعداد کاربر:</span>
                  <span className="text-foreground">{plan.user_limit}</span>
                </div>
                <div className="flex justify-between text-muted-foreground">
                  <span>فروش:</span>
                  <span className="text-foreground">{plan.sales_count || 0}</span>
                </div>
              </div>

              <div className="text-xl font-bold text-primary mb-4 font-mono">
                {formatPrice(plan.price)}
              </div>

              <div className="flex items-center gap-2 pt-4 border-t border-border">
                <button
                  onClick={() => openEditPlanModal(plan)}
                  className="flex-1 btn-secondary text-sm flex items-center justify-center gap-1"
                  data-testid={`edit-plan-${plan.id}`}
                >
                  <Edit2 size={16} />
                  ویرایش
                </button>
                <button
                  onClick={() => handleDeletePlan(plan.id)}
                  className="p-2 text-muted-foreground hover:text-destructive"
                  data-testid={`delete-plan-${plan.id}`}
                >
                  <Trash2 size={18} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Plan Modal */}
      {showPlanModal && (
        <div className="modal-overlay" onClick={() => setShowPlanModal(false)}>
          <div className="modal-content p-6 max-w-lg" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-foreground mb-6">
              {editingPlan ? 'ویرایش پلن' : 'افزودن پلن'}
            </h2>
            <form onSubmit={handlePlanSubmit} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="col-span-2">
                  <label className="block text-sm text-muted-foreground mb-2">نام پلن</label>
                  <input
                    type="text"
                    value={planForm.name}
                    onChange={(e) => setPlanForm({ ...planForm, name: e.target.value })}
                    className="input"
                    placeholder="پلن یک ماهه"
                    required
                    data-testid="plan-name-input"
                  />
                </div>
                <div className="col-span-2">
                  <label className="block text-sm text-muted-foreground mb-2">دسته‌بندی</label>
                  <select
                    value={planForm.category_id}
                    onChange={(e) => setPlanForm({ ...planForm, category_id: e.target.value })}
                    className="input"
                    data-testid="plan-category-select"
                  >
                    <option value="">بدون دسته‌بندی</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-muted-foreground mb-2">قیمت (تومان)</label>
                  <input
                    type="number"
                    value={planForm.price}
                    onChange={(e) => setPlanForm({ ...planForm, price: e.target.value })}
                    className="input"
                    placeholder="50000"
                    required
                    data-testid="plan-price-input"
                  />
                </div>
                <div>
                  <label className="block text-sm text-muted-foreground mb-2">تعداد کاربر</label>
                  <input
                    type="number"
                    value={planForm.user_limit}
                    onChange={(e) => setPlanForm({ ...planForm, user_limit: e.target.value })}
                    className="input"
                    placeholder="1"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm text-muted-foreground mb-2">مدت (روز)</label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      value={planForm.duration_days}
                      onChange={(e) => setPlanForm({ ...planForm, duration_days: e.target.value })}
                      className="input flex-1"
                      placeholder="30"
                      disabled={planForm.duration_unlimited}
                      data-testid="plan-duration-input"
                    />
                    <label className="flex items-center gap-1 text-xs text-muted-foreground whitespace-nowrap">
                      <input
                        type="checkbox"
                        checked={planForm.duration_unlimited}
                        onChange={(e) => setPlanForm({ ...planForm, duration_unlimited: e.target.checked, duration_days: '' })}
                        className="w-4 h-4"
                      />
                      <Infinity size={14} /> نامحدود
                    </label>
                  </div>
                </div>
                <div>
                  <label className="block text-sm text-muted-foreground mb-2">حجم (GB)</label>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      value={planForm.traffic_gb}
                      onChange={(e) => setPlanForm({ ...planForm, traffic_gb: e.target.value })}
                      className="input flex-1"
                      placeholder="50"
                      disabled={planForm.traffic_unlimited}
                      data-testid="plan-traffic-input"
                    />
                    <label className="flex items-center gap-1 text-xs text-muted-foreground whitespace-nowrap">
                      <input
                        type="checkbox"
                        checked={planForm.traffic_unlimited}
                        onChange={(e) => setPlanForm({ ...planForm, traffic_unlimited: e.target.checked, traffic_gb: '' })}
                        className="w-4 h-4"
                      />
                      <Infinity size={14} /> نامحدود
                    </label>
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-sm text-muted-foreground mb-2">توضیحات</label>
                <textarea
                  value={planForm.description}
                  onChange={(e) => setPlanForm({ ...planForm, description: e.target.value })}
                  className="input min-h-[60px]"
                  placeholder="توضیحات اختیاری..."
                />
              </div>
              <div>
                <label className="block text-sm text-muted-foreground mb-2">سرورها</label>
                <div className="flex flex-wrap gap-2">
                  {servers.map((server) => (
                    <button
                      key={server.id}
                      type="button"
                      onClick={() => toggleServer(server.id)}
                      className={`px-3 py-1.5 rounded-lg text-sm transition-colors ${
                        planForm.server_ids.includes(server.id)
                          ? 'bg-primary/20 text-primary border border-primary/30'
                          : 'bg-muted text-muted-foreground border border-border'
                      }`}
                    >
                      {server.name}
                    </button>
                  ))}
                  {servers.length === 0 && (
                    <span className="text-muted-foreground text-sm">سروری موجود نیست</span>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-4">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={planForm.is_active}
                    onChange={(e) => setPlanForm({ ...planForm, is_active: e.target.checked })}
                    className="w-4 h-4"
                  />
                  <span className="text-sm text-foreground">فعال</span>
                </label>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={planForm.is_test}
                    onChange={(e) => setPlanForm({ ...planForm, is_test: e.target.checked })}
                    className="w-4 h-4"
                  />
                  <span className="text-sm text-foreground">پلن تست</span>
                </label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-plan-btn">
                  {editingPlan ? 'بروزرسانی' : 'افزودن'}
                </button>
                <button type="button" onClick={() => setShowPlanModal(false)} className="btn-secondary">
                  انصراف
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Category Modal */}
      {showCategoryModal && (
        <div className="modal-overlay" onClick={() => setShowCategoryModal(false)}>
          <div className="modal-content p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold text-foreground mb-6">
              {editingCategory ? 'ویرایش دسته‌بندی' : 'افزودن دسته‌بندی'}
            </h2>
            <form onSubmit={handleCategorySubmit} className="space-y-4">
              <div>
                <label className="block text-sm text-muted-foreground mb-2">نام دسته‌بندی</label>
                <input
                  type="text"
                  value={categoryForm.name}
                  onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                  className="input"
                  placeholder="پلن‌های ماهانه"
                  required
                  data-testid="category-name-input"
                />
              </div>
              <div>
                <label className="block text-sm text-muted-foreground mb-2">توضیحات</label>
                <textarea
                  value={categoryForm.description}
                  onChange={(e) => setCategoryForm({ ...categoryForm, description: e.target.value })}
                  className="input min-h-[60px]"
                  placeholder="توضیحات اختیاری..."
                />
              </div>
              <div>
                <label className="block text-sm text-muted-foreground mb-2">رنگ</label>
                <div className="flex items-center gap-3">
                  <input
                    type="color"
                    value={categoryForm.color}
                    onChange={(e) => setCategoryForm({ ...categoryForm, color: e.target.value })}
                    className="w-12 h-10 rounded cursor-pointer"
                  />
                  <input
                    type="text"
                    value={categoryForm.color}
                    onChange={(e) => setCategoryForm({ ...categoryForm, color: e.target.value })}
                    className="input flex-1 font-mono"
                    placeholder="#3b82f6"
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="cat_active"
                  checked={categoryForm.is_active}
                  onChange={(e) => setCategoryForm({ ...categoryForm, is_active: e.target.checked })}
                  className="w-4 h-4"
                />
                <label htmlFor="cat_active" className="text-sm text-foreground">فعال</label>
              </div>
              <div className="flex gap-3 pt-4">
                <button type="submit" className="btn-primary flex-1" data-testid="save-category-btn">
                  {editingCategory ? 'بروزرسانی' : 'افزودن'}
                </button>
                <button type="button" onClick={() => setShowCategoryModal(false)} className="btn-secondary">
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
