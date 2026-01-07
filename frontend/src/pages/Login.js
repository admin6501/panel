import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { Shield, User, Lock, AlertCircle, Globe } from 'lucide-react';
import toast from 'react-hot-toast';

const Login = () => {
  const { t, i18n } = useTranslation();
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const isRTL = i18n.language === 'fa';

  // Redirect if already logged in
  React.useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await login(username, password);
      toast.success(t('common.success'));
      navigate('/');
    } catch (err) {
      setError(t('login.error'));
    } finally {
      setLoading(false);
    }
  };

  const toggleLanguage = () => {
    const newLang = i18n.language === 'fa' ? 'en' : 'fa';
    i18n.changeLanguage(newLang);
    localStorage.setItem('language', newLang);
  };

  return (
    <div className="min-h-screen bg-dark-bg flex items-center justify-center p-4">
      {/* Language Toggle */}
      <button
        onClick={toggleLanguage}
        className={`absolute top-4 ${isRTL ? 'left-4' : 'right-4'} flex items-center gap-2 px-3 py-2 bg-dark-card border border-dark-border rounded-lg text-dark-text hover:text-white transition-colors`}
      >
        <Globe className="w-5 h-5" />
        <span>{i18n.language === 'fa' ? 'English' : 'فارسی'}</span>
      </button>

      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-primary-600/20 rounded-full mb-4">
            <Shield className="w-10 h-10 text-primary-500" />
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">{t('app.title')}</h1>
          <p className="text-dark-muted">{t('login.subtitle')}</p>
        </div>

        {/* Login Form */}
        <div className="bg-dark-card border border-dark-border rounded-xl p-6 shadow-2xl">
          <h2 className="text-xl font-semibold text-white mb-6 text-center">
            {t('login.title')}
          </h2>

          {error && (
            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/50 rounded-lg flex items-center gap-2 text-red-400">
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('login.username')}
              </label>
              <div className="relative">
                <User className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} />
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500 focus:ring-1 focus:ring-primary-500 transition-colors`}
                  placeholder={t('login.username')}
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-dark-text text-sm font-medium mb-2">
                {t('login.password')}
              </label>
              <div className="relative">
                <Lock className={`absolute ${isRTL ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 w-5 h-5 text-dark-muted`} />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={`w-full bg-dark-bg border border-dark-border rounded-lg py-3 ${isRTL ? 'pr-10 pl-4' : 'pl-10 pr-4'} text-white placeholder-dark-muted focus:border-primary-500 focus:ring-1 focus:ring-primary-500 transition-colors`}
                  placeholder={t('login.password')}
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-primary-600 hover:bg-primary-700 text-white font-medium py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                t('login.submit')
              )}
            </button>
          </form>

          <div className="mt-6 pt-4 border-t border-dark-border text-center">
            <p className="text-dark-muted text-sm">
              Default: admin / admin
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
