// Copyright (c) 2025, NVIDIA CORPORATION.  All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package ringbuffer

import (
	"context"
	"errors"

	"k8s.io/klog/v2"

	platformconnector "github.com/nvidia/nvsentinel/data-models/pkg/protos"
	"k8s.io/client-go/util/workqueue"
)

type RingBuffer struct {
	ringBufferIdentifier string
	healthMetricQueue    workqueue.TypedRateLimitingInterface[*platformconnector.HealthEvents]
	ctx                  context.Context
}

func NewRingBuffer(ringBufferName string, ctx context.Context) *RingBuffer {
	workqueue.SetProvider(prometheusMetricsProvider{})
	queue := workqueue.NewTypedRateLimitingQueueWithConfig(
		workqueue.DefaultTypedControllerRateLimiter[*platformconnector.HealthEvents](),
		workqueue.TypedRateLimitingQueueConfig[*platformconnector.HealthEvents]{
			Name: ringBufferName,
		},
	)

	return &RingBuffer{
		ringBufferIdentifier: ringBufferName,
		healthMetricQueue:    queue,
		ctx:                  ctx,
	}
}

func (rb *RingBuffer) Enqueue(data *platformconnector.HealthEvents) {
	rb.healthMetricQueue.Add(data)
}

func (rb *RingBuffer) Dequeue() *platformconnector.HealthEvents {
	healthEvents, quit := rb.healthMetricQueue.Get()
	if quit {
		klog.Infof("quitting from queue processing")
		return nil
	}

	klog.Infof("Successfully got item %v ", healthEvents)

	if errors.Is(rb.ctx.Err(), context.Canceled) {
		klog.Info("Processing cancelled")
		return nil
	}

	return healthEvents
}

func (rb *RingBuffer) HealthMetricEleProcessingCompleted(data *platformconnector.HealthEvents) {
	rb.healthMetricQueue.Done(data)
}

func (rb *RingBuffer) HealthMetricEleProcessingFailed(data *platformconnector.HealthEvents) {
	rb.healthMetricQueue.Forget(data)
}

func (rb *RingBuffer) ShutDownHealthMetricQueue() {
	rb.healthMetricQueue.ShutDown()
}

func (rb *RingBuffer) CurrentLength() int {
	return rb.healthMetricQueue.Len()
}
