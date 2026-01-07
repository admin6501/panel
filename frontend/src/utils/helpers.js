// Format bytes to human readable
export const formatBytes = (bytes, decimals = 2) => {
  if (!bytes || bytes === 0) return '0 Bytes';

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

// Parse bytes from string (e.g., "10 GB" -> bytes)
export const parseBytes = (value, unit) => {
  const units = {
    'Bytes': 1,
    'KB': 1024,
    'MB': 1024 * 1024,
    'GB': 1024 * 1024 * 1024,
    'TB': 1024 * 1024 * 1024 * 1024
  };
  return value * (units[unit] || 1);
};

// Format date
export const formatDate = (dateString) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('fa-IR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
};

// Format date for input
export const formatDateForInput = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toISOString().split('T')[0];
};

// Get status color
export const getStatusColor = (status) => {
  const colors = {
    active: 'bg-green-500',
    disabled: 'bg-gray-500',
    expired: 'bg-red-500',
    data_limit_reached: 'bg-orange-500'
  };
  return colors[status] || 'bg-gray-500';
};

// Get role display name
export const getRoleDisplayName = (role, t) => {
  const roles = {
    super_admin: t('users.superAdmin'),
    admin: t('users.admin'),
    viewer: t('users.viewer')
  };
  return roles[role] || role;
};
