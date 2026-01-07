import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import {
  Shield,
  Wifi,
  WifiOff,
  Clock,
  Database,
  Download,
  Upload,
  Calendar,
  CheckCircle,
  XCircle,
  AlertCircle,
  RefreshCw,
  Zap
} from 'lucide-react';
import axios from 'axios';

const API_URL = process.env.REACT_APP_BACKEND_URL || '/api';

// Format bytes to human readable
const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 بایت';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['بایت', 'کیلوبایت', 'مگابایت', 'گیگابایت', 'ترابایت'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

// Format date to Persian
const formatDate = (dateString) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('fa-IR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
};

// Calculate remaining days
const getRemainingDays = (expiryDate) => {
  if (!expiryDate) return null;
  const now = new Date();
  const expiry = new Date(expiryDate);
  const diff = expiry - now;
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
  return days;
};

const Subscription = () => {
  const { clientId } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchData();
    // Auto refresh every 30 seconds
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, [clientId]);

  const fetchData = async () => {
    try {
      const response = await axios.get(`${API_URL}/sub/${clientId}`);
      setData(response.data);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.detail || 'خطا در دریافت اطلاعات');
    } finally {
      setLoading(false);
    }
  };

  const getStatusInfo = (status) => {
    const statusMap = {
      active: { label: 'فعال', color: 'text-green-500', bg: 'bg-green-500/20', icon: CheckCircle },
      disabled: { label: 'غیرفعال', color: 'text-gray-500', bg: 'bg-gray-500/20', icon: XCircle },
      expired: { label: 'منقضی شده', color: 'text-red-500', bg: 'bg-red-500/20', icon: AlertCircle },
      data_limit_reached: { label: 'حجم تمام شده', color: 'text-orange-500', bg: 'bg-orange-500/20', icon: AlertCircle }
    };
    return statusMap[status] || statusMap.active;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center" dir="rtl">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-t-2 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-slate-400">در حال بارگذاری...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center" dir="rtl">
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-8 text-center max-w-md">
          <XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h1 className="text-xl font-bold text-white mb-2">خطا</h1>
          <p className="text-slate-400">{error}</p>
        </div>
      </div>
    );
  }

  const statusInfo = getStatusInfo(data.status);
  const StatusIcon = statusInfo.icon;
  const remainingDays = getRemainingDays(data.expiry_date);
  const usagePercent = data.data_limit ? Math.min((data.data_used / data.data_limit) * 100, 100) : 0;

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 py-8 px-4" dir="rtl">
      <div className="max-w-lg mx-auto space-y-6">
        {/* Header */}
        <div className="text-center">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-blue-500/20 rounded-full mb-4">
            <Shield className="w-10 h-10 text-blue-500" />
          </div>
          <h1 className="text-2xl font-bold text-white mb-1">{data.name}</h1>
          <p className="text-slate-400">اطلاعات اشتراک WireGuard</p>
        </div>

        {/* Status Card */}
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className={`p-3 rounded-xl ${statusInfo.bg}`}>
                <StatusIcon className={`w-6 h-6 ${statusInfo.color}`} />
              </div>
              <div>
                <p className="text-slate-400 text-sm">وضعیت</p>
                <p className={`font-bold text-lg ${statusInfo.color}`}>{statusInfo.label}</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {data.is_online ? (
                <span className="flex items-center gap-1 px-3 py-1 bg-green-500/20 text-green-500 rounded-full text-sm">
                  <Wifi className="w-4 h-4" />
                  آنلاین
                </span>
              ) : (
                <span className="flex items-center gap-1 px-3 py-1 bg-slate-600/50 text-slate-400 rounded-full text-sm">
                  <WifiOff className="w-4 h-4" />
                  آفلاین
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Data Usage Card */}
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <h2 className="text-white font-semibold mb-4 flex items-center gap-2">
            <Database className="w-5 h-5 text-blue-500" />
            مصرف داده
          </h2>
          
          {data.data_limit ? (
            <>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-slate-400">مصرف شده</span>
                <span className="text-white">{formatBytes(data.data_used)}</span>
              </div>
              <div className="w-full bg-slate-700 rounded-full h-3 mb-2">
                <div
                  className={`h-3 rounded-full transition-all ${
                    usagePercent > 90 ? 'bg-red-500' : usagePercent > 70 ? 'bg-yellow-500' : 'bg-green-500'
                  }`}
                  style={{ width: `${usagePercent}%` }}
                />
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-slate-400">باقی‌مانده</span>
                <span className={data.data_remaining > 0 ? 'text-green-500' : 'text-red-500'}>
                  {data.data_remaining > 0 ? formatBytes(data.data_remaining) : 'تمام شده'}
                </span>
              </div>
              <div className="flex justify-between text-sm mt-1">
                <span className="text-slate-400">کل حجم</span>
                <span className="text-white">{formatBytes(data.data_limit)}</span>
              </div>
            </>
          ) : (
            <p className="text-green-500 text-center py-4">حجم نامحدود ♾️</p>
          )}
        </div>

        {/* Download/Upload Card */}
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <Download className="w-5 h-5 text-green-500" />
              <span className="text-slate-400 text-sm">دانلود</span>
            </div>
            <p className="text-white font-bold text-lg">{formatBytes(data.download)}</p>
          </div>
          <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <Upload className="w-5 h-5 text-blue-500" />
              <span className="text-slate-400 text-sm">آپلود</span>
            </div>
            <p className="text-white font-bold text-lg">{formatBytes(data.upload)}</p>
          </div>
        </div>

        {/* Time Info Card */}
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-6">
          <h2 className="text-white font-semibold mb-4 flex items-center gap-2">
            <Clock className="w-5 h-5 text-blue-500" />
            اطلاعات زمانی
          </h2>

          {data.start_on_first_connect && !data.timer_started ? (
            <div className="text-center py-4">
              <div className="inline-flex items-center justify-center w-12 h-12 bg-yellow-500/20 rounded-full mb-2">
                <Clock className="w-6 h-6 text-yellow-500" />
              </div>
              <p className="text-yellow-500 font-medium">در انتظار اولین اتصال</p>
              <p className="text-slate-400 text-sm mt-1">
                پس از اولین اتصال، {data.expiry_days} روز اعتبار شروع می‌شود
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {data.expiry_date ? (
                <>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">تاریخ انقضا</span>
                    <span className="text-white">{formatDate(data.expiry_date)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">روز باقی‌مانده</span>
                    <span className={remainingDays > 0 ? 'text-green-500 font-bold' : 'text-red-500 font-bold'}>
                      {remainingDays > 0 ? `${remainingDays} روز` : 'منقضی شده'}
                    </span>
                  </div>
                </>
              ) : (
                <p className="text-green-500 text-center py-4">بدون محدودیت زمانی ♾️</p>
              )}

              {data.first_connection_at && (
                <div className="flex justify-between items-center pt-2 border-t border-slate-700">
                  <span className="text-slate-400">اولین اتصال</span>
                  <span className="text-white text-sm">{formatDate(data.first_connection_at)}</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Auto Renew Info */}
        {data.auto_renew && (
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-2xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <Zap className="w-5 h-5 text-yellow-500" />
              <span className="text-yellow-500 font-medium">تمدید خودکار فعال</span>
            </div>
            <p className="text-slate-400 text-sm">
              این اشتراک پس از اتمام حجم یا زمان، به صورت خودکار تمدید می‌شود.
            </p>
            {data.renew_count > 0 && (
              <p className="text-slate-400 text-sm mt-1">
                تعداد تمدید: <span className="text-white">{data.renew_count} بار</span>
              </p>
            )}
          </div>
        )}

        {/* Created At */}
        <div className="bg-slate-800/50 backdrop-blur-sm border border-slate-700 rounded-2xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Calendar className="w-5 h-5 text-slate-400" />
              <span className="text-slate-400">تاریخ ایجاد</span>
            </div>
            <span className="text-white">{formatDate(data.created_at)}</span>
          </div>
        </div>

        {/* Refresh Button */}
        <button
          onClick={fetchData}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 rounded-xl transition-colors flex items-center justify-center gap-2"
        >
          <RefreshCw className="w-5 h-5" />
          بروزرسانی اطلاعات
        </button>

        {/* Footer */}
        <p className="text-center text-slate-500 text-sm">
          آخرین بروزرسانی: {new Date().toLocaleTimeString('fa-IR')}
        </p>
      </div>
    </div>
  );
};

export default Subscription;
