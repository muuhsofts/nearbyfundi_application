import React from 'react';
import { Chip } from '@mui/material';
import {
    Pending as PendingIcon,
    CheckCircle as CheckCircleIcon,
    Schedule as ScheduleIcon,
    Cancel as CancelIcon,
} from '@mui/icons-material';

const StatusChip = ({ status }) => {
    const statusMap = {
        pending: {
            bg: '#fef3c7',
            color: '#b45309',
            border: '#f59e0b',
            icon: <PendingIcon sx={{ fontSize: 15 }} />,
            label: 'Pending',
        },
        accepted: {
            bg: '#dbeafe',
            color: '#1d4ed8',
            border: '#3b82f6',
            icon: <CheckCircleIcon sx={{ fontSize: 15 }} />,
            label: 'Accepted',
        },
        in_progress: {
            bg: '#e0e7ff',
            color: '#4338ca',
            border: '#6366f1',
            icon: <ScheduleIcon sx={{ fontSize: 15 }} />,
            label: 'In Progress',
        },
        completed: {
            bg: '#d1fae5',
            color: '#047857',
            border: '#10b981',
            icon: <CheckCircleIcon sx={{ fontSize: 15 }} />,
            label: 'Completed',
        },
        cancelled: {
            bg: '#f3f4f6',
            color: '#4b5563',
            border: '#9ca3af',
            icon: <CancelIcon sx={{ fontSize: 15 }} />,
            label: 'Cancelled',
        },
        rejected: {
            bg: '#fee2e2',
            color: '#b91c1c',
            border: '#ef4444',
            icon: <CancelIcon sx={{ fontSize: 15 }} />,
            label: 'Rejected',
        },
        active: {
            bg: '#d1fae5',
            color: '#047857',
            border: '#10b981',
            icon: <CheckCircleIcon sx={{ fontSize: 15 }} />,
            label: 'Active',
        },
        inactive: {
            bg: '#f3f4f6',
            color: '#4b5563',
            border: '#9ca3af',
            icon: <CancelIcon sx={{ fontSize: 15 }} />,
            label: 'Inactive',
        },
        pending_verification: {
            bg: '#fef3c7',
            color: '#b45309',
            border: '#f59e0b',
            icon: <PendingIcon sx={{ fontSize: 15 }} />,
            label: 'Pending Verification',
        },
    };

    const config = statusMap[status] || statusMap.pending;

    return (
        <Chip
            icon={config.icon}
            label={config.label}
            size="small"
            sx={{
                backgroundColor: config.bg,
                color: config.color,
                fontWeight: 700,
                border: `1.5px solid ${config.border}`,
                height: 28,
                '& .MuiChip-icon': { color: config.color },
            }}
        />
    );
};

export default StatusChip;