/*
 * Copyright (c) 2024, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "./detail/quantization.cuh"

#include <cuvs/neighbors/quantization.hpp>

namespace cuvs::neighbors::quantization {

template <typename T, typename QuantI>
void ScalarQuantizer<T, QuantI>::train(raft::resources const& res,
                                       params params,
                                       raft::device_matrix_view<const T, int64_t> dataset)
{
  ASSERT(params.quantile > 0.0 && params.quantile <= 1.0,
         "quantile for scalar quantization needs to be within (0, 1]");

  // conditional: search for quantiles / min / max
  if (!is_trained_) {
    auto [min, max] = detail::quantile_min_max(res, dataset, params.quantile);

    // persist settings in params
    constexpr int64_t range_q_type = static_cast<int64_t>(std::numeric_limits<QuantI>::max()) -
                                     static_cast<int64_t>(std::numeric_limits<QuantI>::min());
    min_        = min;
    max_        = max;
    scalar_     = max_ > min ? double(range_q_type) / double(max_ - min_) : 1.0;
    is_trained_ = true;
  }
}

template <typename T, typename QuantI>
void ScalarQuantizer<T, QuantI>::train(raft::resources const& res,
                                       params params,
                                       raft::host_matrix_view<const T, int64_t> dataset)
{
  ASSERT(params.quantile > 0.0 && params.quantile <= 1.0,
         "quantile for scalar quantization needs to be within (0, 1]");

  // conditional: search for quantiles / min / max
  if (!is_trained_) {
    auto [min, max] = detail::quantile_min_max(res, dataset, params.quantile);

    // persist settings in params
    constexpr int64_t range_q_type = static_cast<int64_t>(std::numeric_limits<QuantI>::max()) -
                                     static_cast<int64_t>(std::numeric_limits<QuantI>::min());
    min_        = min;
    max_        = max;
    scalar_     = max_ > min ? double(range_q_type) / double(max_ - min_) : 1.0;
    is_trained_ = true;
  }
}

template <typename T, typename QuantI>
raft::device_matrix<QuantI, int64_t> ScalarQuantizer<T, QuantI>::transform(
  raft::resources const& res, raft::device_matrix_view<const T, int64_t> dataset)
{
  ASSERT(is_trained_, "ScalarQuantizer needs to be trained first!");
  return detail::scalar_transform<T, QuantI>(res, dataset, scalar_, min_);
}

template <typename T, typename QuantI>
raft::host_matrix<QuantI, int64_t> ScalarQuantizer<T, QuantI>::transform(
  raft::resources const& res, raft::host_matrix_view<const T, int64_t> dataset)
{
  ASSERT(is_trained_, "ScalarQuantizer needs to be trained first!");
  return detail::scalar_transform<T, QuantI>(res, dataset, scalar_, min_);
}

#define CUVS_INST_QUANTIZATION(T, QuantI) \
  template struct cuvs::neighbors::quantization::ScalarQuantizer<T, QuantI>;

CUVS_INST_QUANTIZATION(double, int8_t);
CUVS_INST_QUANTIZATION(float, int8_t);
CUVS_INST_QUANTIZATION(half, int8_t);

#undef CUVS_INST_QUANTIZATION

}  // namespace cuvs::neighbors::quantization