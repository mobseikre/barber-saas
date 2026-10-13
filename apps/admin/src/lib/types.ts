export type BarberStatus = 'pending' | 'active' | 'suspended' | 'rejected';
export type BookingStatus = 'confirmed' | 'completed' | 'no_show' | 'cancelled';
export type CancelReason = 'sick' | 'emergency' | 'other';

export interface AdminBarber {
  id: string;
  display_name: string;
  status: BarberStatus;
  is_vip: boolean;
  subscription_ends_at: string | null;
  created_at: string;
  rating_avg: number;
  rating_count: number;
  profile_id: string | null;
  phone: string | null;
  salon_id: string;
  salon_name: string;
  address: string | null;
  is_salon_owner: boolean;
  area_id: string;
  area_name: string;
  city_id: string;
  city_name: string;
  latitude: number | null;
  longitude: number | null;
  is_bookable: boolean;
  bookings_month: number;
}

export interface SubscriptionPlan {
  id: string;
  months: number;
  price: number;
  is_active: boolean;
  updated_at: string;
}

export interface AdminAction {
  id: string;
  actor_id: string;
  action: 'set_barber_status' | 'activate_subscription' | 'unblock_customer' | 'save_subscription_plan' | 'reset_password';
  target_id: string | null;
  details: Record<string, unknown>;
  created_at: string;
  actor: { full_name: string } | null;
}

export interface AdminSalon {
  id: string;
  name: string;
  address: string | null;
  created_at: string;
  area_id: string;
  area_name: string;
  city_id: string;
  city_name: string;
  owner_name: string | null;
  owner_phone: string | null;
  barbers_total: number;
  barbers_subscribed: number;
  bookings_month: number;
  rating_avg: number;
}

export interface SubscriptionPayment {
  id: string;
  barber_id: string;
  barber_name: string;
  amount: number;
  paid_at: string;
  period_start: string;
  period_end: string;
  note: string | null;
  recorded_by_name: string | null;
  plan_id: string | null;
  plan_months: number | null;
  plan_price: number | null;
  override_reason: string | null;
}

export interface Cancellations {
  barber_id: string;
  cancelled_total: number;
  sick: number;
  emergency: number;
  other: number;
}

export interface Customer {
  id: string;
  full_name: string;
  phone: string;
  no_show_count: number;
  blocked_at: string | null;
  created_at: string;
}

export interface City {
  id: string;
  name: string;
  sort_order: number;
}

export interface Area {
  id: string;
  city_id: string;
  name: string;
  sort_order: number;
}

export interface BookingRow {
  id: string;
  time_range: string;
  status: BookingStatus;
  source: 'app' | 'manual';
  price: number;
  customer_name: string | null;
  cancel_reason: CancelReason | null;
  cancel_note: string | null;
  customer: { full_name: string; phone: string } | null;
  barber: { display_name: string; salon: { name: string } | null } | null;
  service: { name_ar: string } | null;
}
