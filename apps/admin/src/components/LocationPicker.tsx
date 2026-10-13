'use client';

import dynamic from 'next/dynamic';

import { Loading } from './ui';

const SalonMap = dynamic(() => import('./SalonMap'), { ssr: false, loading: () => <Loading /> });

export function LocationPicker(props: { latitude: number | null; longitude: number | null; onChange: (lat: number, lng: number) => void }) {
  return <SalonMap {...props} />;
}
